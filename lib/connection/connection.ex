use Bitwise

defmodule Hadean.RTSPConnection do
  use GenServer
  alias Hadean.Packet.RTPPacketHeader
  alias Hadean.Packet.VideoPacket
  alias Hadean.Parsers.SDPParser
  alias Hadean.Parsers.UrlParser
  alias Hadean.Parsers.DescribeResponseParser
  alias Hadean.Commands.Describe
  alias Hadean.Commands.Setup
  alias Hadean.Commands.Pause
  alias Hadean.Commands.Options
  alias Hadean.Commands.Teardown
  alias Hadean.Commands.Play
  alias Hadean.Authentication.Digest

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
            context: nil

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

  def init(base_url) do
    {server, port} = UrlParser.parse(base_url)

    state = %__MODULE__{
      url: base_url,
      server: server,
      port: port
    }

    {:ok, state, 10_000_000}
  end

  def start_link({url, username, password}) do
    GenServer.start_link(__MODULE__, {url, username, password}, name: __MODULE__)
  end

  def start_link(url) do
    GenServer.start_link(__MODULE__, url)
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
    state = handle_audio(state)
    state = handle_audio(state)

    {:reply, state, state}
  end

  def handle_call(:setup_audio, _from, state) do
    state = handle_audio(state)

    {:reply, state, state}
  end

  def handle_call(:setup_video, _from, state) do
    state = handle_video(state)

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

    # TODO abhi: spawn as a Task under supervision
    streamer_pid = spawn(__MODULE__, :start, [state.socket, state.context])
    # Task.start(fn -> start(state.socket) end)
    {:reply, state,
     state
     |> Map.put(:streamer_pid, streamer_pid)
     |> Map.put(:cseq_num, state.cseq_num + 1)}
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
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, state}
  end

  defp handle_audio(state) do
    if state.context.audio_track != nil do
      handle(state.context.audio_track.id, state)
    end
  end

  defp handle_video(state) do
    if state.context.video_track != nil do
      handle(state.context.video_track.id, state)
    end
  end

  defp handle(id, state) do
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
          packet = AudioPacket.parse(rtp_header, rtp_payload, context.audio_track.codec_info)
      end
    end

    start(socket, context)
  end
end
