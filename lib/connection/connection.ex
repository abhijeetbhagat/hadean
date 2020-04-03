use Bitwise

defmodule Hadean.RTSPConnection do
  use GenServer
  alias Hadean.Packet.RTPPacketHeader
  alias Hadean.Packet.VideoPacket
  alias Hadean.Packet.AudioPacket
  alias Hadean.Parsers.SDPParser
  alias Hadean.Parsers.UrlParser
  alias Hadean.Parsers.DescribeResponseParser
  alias Hadean.Parsers.SetupResponseParser
  alias Hadean.Commands.Describe
  alias Hadean.Commands.Setup
  alias Hadean.Commands.Pause
  alias Hadean.Commands.Options
  alias Hadean.Commands.Teardown
  alias Hadean.Commands.Play
  alias Hadean.Authentication.Digest
  alias Hadean.Connection.SocketPairGenerator

  @typep s :: port()

  defstruct url: nil,
            server: nil,
            port: 0,
            socket: nil,
            session: 0,
            # interleaved or UDP
            mode: :interleaved,
            cseq_num: 0,
            streamer_pid: 0,
            auth_pid: 0,
            auth_needed: false,
            context: nil,
            transport: :unknown

  def init([url, server, port]) do
    state = %__MODULE__{
      url: url,
      server: server,
      port: port
    }

    {:ok, state}
  end

  def init({url, username, password}) do
    {server, port} = UrlParser.parse(url)

    pid = Digest.start_link({username, password})

    state = %__MODULE__{
      url: url,
      server: server,
      port: port
    }

    state |> Map.put(:auth_agent, pid)

    {:ok, state, 10_000_000}
  end

  def init(base_url, mode) do
    {server, port} = UrlParser.parse(base_url)

    state = %__MODULE__{
      url: base_url,
      server: server,
      port: port,
      transport: mode
    }

    {:ok, state, 10_000_000}
  end

  def start_link({url, username, password}) do
    GenServer.start_link(__MODULE__, {url, username, password}, name: __MODULE__)
  end

  @spec start_link(binary(), :tcp | :udp) ::
          :ignore | {:ok, PID} | {:error, {:already_started, pid}}
  def start_link(url, mode) do
    GenServer.start_link(__MODULE__, url, mode)
  end

  def handle_call(:connect, _from, state) do
    socket =
      case :gen_tcp.connect(state.server, state.port, [:binary, active: false, packet: :raw]) do
        {:ok, socket} -> socket
        {:error, reason} -> raise reason
      end

    {:reply, state, state |> Map.put(:socket, socket)}
  end

  def handle_call(:options, _from, state) do
    :gen_tcp.send(
      state.socket,
      Options.create(state.url, state.cseq_num)
    )

    case :gen_tcp.recv(state.socket, 0) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise reason
    end

    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:setup_all, _from, state) do
    state = handle_audio(state.transport, state)
    state = handle_video(state.transport, state)

    {:reply, state, state}
  end

  def handle_call(:setup_audio, _from, state) do
    state = handle_audio(state.transport, state)

    {:reply, state, state}
  end

  def handle_call(:setup_video, _from, state) do
    state = handle_video(state.transport, state)

    {:reply, state, state}
  end

  def handle_call(:describe, _from, state) do
    :gen_tcp.send(
      state.socket,
      Describe.create(state.url, state.cseq_num)
    )

    response =
      case :gen_tcp.recv(state.socket, 0) do
        {:ok, bytes} -> bytes
        {:error, reason} -> raise reason
      end

    context =
      case DescribeResponseParser.parse(response, state.url) do
        :no_auth ->
          SDPParser.parse_sdp(response)

        {:auth_required, digest} ->
          # auth required, so update digest info which already has
          # username and password
          state |> Map.put(:auth_needed, true)
          pid = state.auth_agent
          Digest.update(pid, digest)

          # resend DESCRIBE with auth info
          :gen_tcp.send(
            state.socket,
            Describe.create(state.url, state.cseq_num, Digest.get_str_rep(pid, "DESCRIBE"))
          )

          # now parse the SDP info from the response
          response =
            case :gen_tcp.recv(state.socket, 0) do
              {:ok, bytes} -> bytes
              {:error, reason} -> raise reason
            end

          SDPParser.parse_sdp(response)
      end

    {:reply, state,
     state
     |> Map.put(:context, context)
     |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:play, _from, state) do
    auth =
      case state.auth_needed do
        false ->
          ""

        _ ->
          Digest.get_str_rep(state.auth_pid, "PLAY")
      end

    :gen_tcp.send(
      state.socket,
      Play.create(state.url, state.cseq_num, state.session, auth)
    )

    handle_play(state.transport, state)

    # Task.start(fn -> start(state.socket) end)
    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:pause, _from, state) do
    :gen_tcp.send(
      state.socket,
      case state.auth_needed do
        false ->
          Pause.create(state.url, state.cseq_num, state.context.session)

        _ ->
          pid = state.auth_pid

          Pause.create(
            state.url,
            state.cseq_num,
            state.context.session,
            Digest.get_str_rep(pid, "PAUSE")
          )
      end
    )

    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:teardown, _from, state) do
    pid = state.auth_pid

    :gen_tcp.send(
      state.socket,
      case state.auth_needed do
        false ->
          Teardown.create(state.url, state.cseq_num, state.context.session)

        _ ->
          Teardown.create(
            state.url,
            state.cseq_num,
            state.context.session,
            Digest.get_str_rep(pid, "TEARDOWN")
          )
      end
    )

    Digest.stop(pid)
    # stop streaming process
    Process.exit(state.streamer_pid, :shutdown)

    :gen_tcp.close(state.socket)
    # stop streaming process
    if state.video_rtp_streamer_pid != 0 do
      Process.exit(state.video_rtp_streamer_pid, :shutdown)
      Process.exit(state.video_rtcp_streamer_pid, :shutdown)
    end

    if state.audio_rtp_streamer_pid != 0 do
      Process.exit(state.audio_rtp_streamer_pid, :shutdown)
      Process.exit(state.audio_rtcp_streamer_pid, :shutdown)
    end

    if state.video_rtp_socket != nil do
      :gen_udp.close(state.video_rtp_socket)
      :gen_udp.close(state.video_rtcp_socket)
    end

    if state.audio_rtp_socket != nil do
      :gen_udp.close(state.audio_rtp_socket)
      :gen_udp.close(state.audio_rtcp_socket)
    end
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, state}
  end

  defp handle_audio(:tcp, state) do
    if state.context.audio_track != nil do
      handle(:tcp, state.context.audio_track.id, state)
    end
  end

  defp handle_audio(:udp, state) do
    if state.context.audio_track != nil do
      handle(
        :udp,
        state.context.audio_track.id,
        {:audio_rtp_port, :audio_rtcp_port},
        {:audio_rtp_socket, :audio_rtcp_socket},
        state
      )
    end
  end

  defp handle_video(:tcp, state) do
    if state.context.video_track != nil do
      handle(:tcp, state.context.video_track.id, state)
    end
  end

  defp handle_video(:udp, state) do
    if state.context.video_track != nil do
      handle(
        :udp,
        state.context.video_track.id,
        {:video_rtp_port, :video_rtcp_port},
        {:video_rtp_socket, :video_rtcp_socket},
        state
      )
    end
  end

  defp handle(:tcp, id, state) do
    :gen_tcp.send(
      state.socket,
      case state.auth_needed do
        false ->
          Setup.create(
            state.url,
            state.cseq_num,
            state.context.session,
            id
          )

        _ ->
          pid = state.auth_agent

          Setup.create(
            state.url,
            state.cseq_num,
            state.context.session,
            id,
            Digest.get_str_rep(pid, "SETUP")
          )
      end
    )

    _response = :gen_tcp.recv(state.socket, 0)
    state |> Map.put(:cseq_num, state.cseq_num + 1)
  end

  defp handle(
         :udp,
         id,
         {rtp_port_atom, rtcp_port_atom},
         {rtp_socket_atom, rtcp_socket_atom},
         state
       ) do
    {rtp_socket, rtcp_socket} = SocketPairGenerator.get_pair()
    {{_, rtp_port}, {_, rtcp_port}} = {:inet.port(rtp_socket), :inet.port(rtcp_socket)}

    :gen_tcp.send(
      state.rtsp_socket,
      Setup.create(
        state.url,
        state.cseq_num,
        state.context.session,
        id,
        rtp_port,
        rtcp_port
      )
    )

    response =
      case(:gen_tcp.recv(state.rtsp_socket, 0)) do
        {:ok, response} -> response
        {:error, reason} -> raise reason
      end

    {server_rtp_port, server_rtcp_port} = SetupResponseParser.parse_server_ports(response)

    :gen_udp.send(rtp_socket, state.server, server_rtp_port, "deadface")
    :gen_udp.send(rtcp_socket, state.server, server_rtcp_port, "")

    :gen_udp.send(rtp_socket, state.server, server_rtp_port, "deadface")
    :gen_udp.send(rtcp_socket, state.server, server_rtcp_port, "")

    state
    |> Map.put(:cseq_num, state.cseq_num + 1)
    |> Map.put(rtp_port_atom, server_rtp_port)
    |> Map.put(rtcp_port_atom, server_rtcp_port)
    |> Map.put(rtp_socket_atom, rtp_socket)
    |> Map.put(rtcp_socket_atom, rtcp_socket)
  end

  def connect(pid) do
    GenServer.call(pid, :connect)
  end

  def options(pid) do
    GenServer.call(pid, :options)
  end

  def describe(pid) do
    GenServer.call(pid, :describe)
  end

  # TODO abhi: figure out a way to use regex

  @spec play(PID) :: term
  def play(pid) do
    GenServer.call(pid, :play)
  end

  @spec pause(PID) :: term
  def pause(pid) do
    GenServer.call(pid, :pause)
  end

  @spec setup(PID, :all | :audio | :video) :: term
  def setup(pid, mode) do
    setup_type =
      case mode do
        :all ->
          :setup_all

        :audio ->
          :setup_audio

        :video ->
          :setup_video
      end

    GenServer.call(pid, setup_type)
  end

  @spec teardown(PID) :: term
  def teardown(pid) do
    stop_server(pid)
  end

  @spec stop(PID) :: term
  def stop(pid) do
    stop_server(pid)
  end

  @spec stop_server(PID) :: term
  defp stop_server(pid) do
    GenServer.call(pid, :teardown)
    GenServer.call(pid, :stop)
  end

  def terminate(_reason, _state) do
    IO.puts("Stopped")
    :ok
  end

  @spec start(s, Hadean.Connection.ConnectionContext.t()) :: no_return()
  def start(socket, context) do
    {:ok,
     <<
       magic::integer-8,
       _channel::integer-8,
       len::integer-16
     >>} = :gen_tcp.recv(socket, 4)

    # if magic is '$', then it is start of the rtp data
    if magic == 0x24 do
      {:ok, rtp_data} = :gen_tcp.recv(socket, len)
      {rtp_header, rtp_payload} = RTPPacketHeader.parse_packet(rtp_data)

      case rtp_header.payload_type do
        97 ->
          packet = VideoPacket.parse(rtp_header, rtp_payload)
          IO.puts("frame_type: #{inspect(packet.frame_type)}")

        _ ->
          _packet = AudioPacket.parse(rtp_header, rtp_payload, context.audio_track.codec_info)
      end
    end

    start(socket, context)
  end

  defp handle_play(:tcp, state) do
    streamer_pid = spawn(__MODULE__, :start, [state.socket, state.context])
    # Task.start(fn -> start(state.socket) end)
    {:reply, state, state |> Map.put(:streamer_pid, streamer_pid)}
  end

  defp handle_play(:udp, state) do
    # TODO abhi: spawn as a Task under supervision
    state =
      case state.context.audio_track do
        nil ->
          audio_rtp_streamer_pid =
            spawn(__MODULE__, :start_audio_rtp_stream, [state.audio_rtp_socket, state.context])

          audio_rtcp_streamer_pid =
            spawn(__MODULE__, :start_audio_rtcp_stream, [state.audio_rtcp_socket])

          state
          |> Map.put(:audio_rtp_streamer_pid, audio_rtp_streamer_pid)
          |> Map.put(:audio_rtcp_streamer_pid, audio_rtcp_streamer_pid)

        _ ->
          state
      end

    state =
      case state.context.video_track do
        nil ->
          video_rtp_streamer_pid =
            spawn(__MODULE__, :start_video_rtp_stream, [state.video_rtp_socket, state.context])

          video_rtcp_streamer_pid =
            spawn(__MODULE__, :start_video_rtcp_stream, [state.video_rtcp_socket])

          state
          |> Map.put(:video_rtp_streamer_pid, video_rtp_streamer_pid)
          |> Map.put(:video_rtcp_streamer_pid, video_rtcp_streamer_pid)

        _ ->
          state
      end

    # Task.start(fn -> start(state.socket) end)
    {:reply, state, state}
  end

  def start_video_rtp_stream(socket, context) do
    {:ok, {_addr, _port, rtp_data}} = :gen_udp.recv(socket, 0)
    {rtp_header, rtp_payload} = RTPPacketHeader.parse_packet(rtp_data)

    packet = VideoPacket.parse(rtp_header, rtp_payload)
    IO.puts("frame_type: #{inspect(packet.frame_type)}")

    start_video_rtp_stream(socket, context)
  end

  def start_video_rtcp_stream(socket) do
    :gen_udp.recv(socket, 0)
    IO.puts("video rtcp streamer: recvd rtcp packet")
    start_video_rtcp_stream(socket)
  end

  def start_audio_rtp_stream(socket, context) do
    {:ok, {_addr, _port, rtp_data}} = :gen_udp.recv(socket, 0)
    {rtp_header, rtp_payload} = RTPPacketHeader.parse_packet(rtp_data)

    packet = AudioPacket.parse(rtp_header, rtp_payload, context.audio_track.codec_info)
    IO.puts("audio rtp streamer: #{inspect(packet.type)}")
    start_audio_rtp_stream(socket, context)
  end

  def start_audio_rtcp_stream(socket) do
    :gen_udp.recv(socket, 0)
    IO.puts("audio rtcp streamer: recvd rtcp packet")
    start_audio_rtcp_stream(socket)
  end
end
