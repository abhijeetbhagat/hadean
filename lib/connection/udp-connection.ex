use Bitwise

defmodule Hadean.RTSPOverUDPConnection do
  use GenServer

  alias Hadean.Parsers.RTPPacketParser
  alias Hadean.Parsers.SDPParser
  alias Hadean.Parsers.UrlParser
  alias Hadean.Parsers.SetupResponseParser

  defstruct url: nil,
            server: nil,
            port: 0,
            rtsp_socket: nil,
            video_rtp_socket: nil,
            video_rtcp_socket: nil,
            video_rtp_port: 0,
            video_rtcp_port: 0,
            # interleaved or UDP
            mode: :interleaved,
            cseq_num: 0,
            video_rtp_streamer_pid: 0,
            video_rtcp_streamer_pid: 0,
            context: nil

  def init([base_url, server, port]) do
    state = %__MODULE__{
      url: base_url,
      server: server,
      port: port
    }

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

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def handle_call(:connect, _from, state) do
    # TODO abhi: this socket should be in line mode
    socket =
      case :gen_tcp.connect(state.server, state.port, [:binary, active: false, packet: :raw]) do
        {:ok, socket} -> socket
        {:error, reason} -> raise reason
      end

    {:reply, state, state |> Map.put(:rtsp_socket, socket)}
  end

  def handle_call(:options, _from, state) do
    :gen_tcp.send(
      state.rtsp_socket,
      "OPTIONS #{state.url} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\n\r\n"
    )

    case :gen_tcp.recv(state.rtsp_socket, 0) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise reason
    end

    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:setup, _from, state) do
    state =
      if state.context.audio_track != nil do
        handle(:setup_audio, state)
      end

    state =
      if state.context.video_track != nil do
        handle(:setup_video, state)
      end

    {:reply, state, state}
  end

  def handle_call(:describe, _from, state) do
    :gen_tcp.send(
      state.rtsp_socket,
      "DESCRIBE #{state.url} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nAccept: application/sdp\r\n\r\n"
    )

    response =
      case :gen_tcp.recv(state.rtsp_socket, 0) do
        {:ok, bytes} -> bytes
        {:error, reason} -> raise reason
      end

    context = SDPParser.parse_sdp(response)

    {:reply, state,
     state
     |> Map.put(:context, context)
     |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:play, _from, state) do
    :gen_tcp.send(
      state.rtsp_socket,
      "PLAY #{state.url}/trackID=2 RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nSession: #{
        state.context.session
      }\r\nRange: npt=0.000-\r\n\r\n"
    )

    # TODO abhi: spawn as a Task under supervision
    state =
      case state.context.audio_track do
        nil ->
          audio_rtp_streamer_pid =
            spawn(__MODULE__, :start_audio_rtp_stream, [state.audio_rtp_socket])

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
            spawn(__MODULE__, :start_video_rtp_stream, [state.video_rtp_socket])

          video_rtcp_streamer_pid =
            spawn(__MODULE__, :start_video_rtcp_stream, [state.video_rtcp_socket])

          state
          |> Map.put(:video_rtp_streamer_pid, video_rtp_streamer_pid)
          |> Map.put(:video_rtcp_streamer_pid, video_rtcp_streamer_pid)

        _ ->
          state
      end

    # Task.start(fn -> start(state.socket) end)
    {:reply, state,
     state
     |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:pause, _from, state) do
    IO.puts("sending pause ...")

    :gen_tcp.send(
      state.rtsp_socket,
      "PAUSE #{state.url} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nSession: #{
        state.context.session
      }\r\n\r\n"
    )

    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:teardown, _from, state) do
    :gen_tcp.send(
      state.rtsp_socket,
      "TEARDOWN #{state.url} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nSession: #{
        state.context.session
      }\r\n\r\n"
    )

    # stop streaming process
    Process.exit(state.video_rtp_streamer_pid, :shutdown)
    Process.exit(state.video_rtcp_streamer_pid, :shutdown)

    :gen_tcp.close(state.rtsp_socket)
    :gen_udp.close(state.video_rtp_socket)
    :gen_udp.close(state.video_rtcp_socket)
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, state}
  end

  def handle(:setup_video, state) do
    rtp_port = 35501
    rtcp_port = 35502

    :gen_tcp.send(
      state.rtsp_socket,
      "SETUP #{state.url}/#{state.context.video_track.id} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nTransport: RTP/AVP;unicast;client_port=#{
        rtp_port
      }-#{rtcp_port}\r\nSession: #{state.context.session}\r\n\r\n"
    )

    response =
      case(:gen_tcp.recv(state.rtsp_socket, 0)) do
        {:ok, response} -> response
        {:error, reason} -> raise reason
      end

    {server_rtp_port, server_rtcp_port} = SetupResponseParser.parse_server_ports(response)

    {:ok, video_rtp_socket} = :gen_udp.open(rtp_port, [:binary, active: false])
    {:ok, video_rtcp_socket} = :gen_udp.open(rtcp_port, [:binary, active: false])

    state =
      state
      |> Map.put(:video_rtp_socket, video_rtp_socket)
      |> Map.put(:video_rtcp_socket, video_rtcp_socket)

    :gen_udp.send(state.video_rtp_socket, state.server, server_rtp_port, "deadface")
    :gen_udp.send(state.video_rtcp_socket, state.server, server_rtcp_port, "")

    :gen_udp.send(state.video_rtp_socket, state.server, server_rtp_port, "deadface")
    :gen_udp.send(state.video_rtcp_socket, state.server, server_rtcp_port, "")

    state
    |> Map.put(:cseq_num, state.cseq_num + 1)
    |> Map.put(:video_rtp_port, server_rtp_port)
    |> Map.put(:video_rtcp_port, server_rtcp_port)
  end

  def handle(:setup_audio, state) do
    rtp_port = 35503
    rtcp_port = 35504

    :gen_tcp.send(
      state.rtsp_socket,
      "SETUP #{state.url}/#{state.context.audio_track.id} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nTransport: RTP/AVP;unicast;client_port=#{
        rtp_port
      }-#{rtcp_port}\r\nSession: #{state.context.session}\r\n\r\n"
    )

    response =
      case(:gen_tcp.recv(state.rtsp_socket, 0)) do
        {:ok, response} -> response
        {:error, reason} -> raise reason
      end

    {server_rtp_port, server_rtcp_port} = SetupResponseParser.parse_server_ports(response)

    {:ok, audio_rtp_socket} = :gen_udp.open(rtp_port, [:binary, active: false])
    {:ok, audio_rtcp_socket} = :gen_udp.open(rtcp_port, [:binary, active: false])

    state =
      state
      |> Map.put(:audio_rtp_socket, audio_rtp_socket)
      |> Map.put(:audio_rtcp_socket, audio_rtcp_socket)

    :gen_udp.send(state.audio_rtp_socket, state.server, server_rtp_port, "deadface")
    :gen_udp.send(state.audio_rtcp_socket, state.server, server_rtcp_port, "")

    :gen_udp.send(state.audio_rtp_socket, state.server, server_rtp_port, "deadface")
    :gen_udp.send(state.audio_rtcp_socket, state.server, server_rtcp_port, "")

    state
    |> Map.put(:cseq_num, state.cseq_num + 1)
    |> Map.put(:audio_rtp_port, server_rtp_port)
    |> Map.put(:audio_rtcp_port, server_rtcp_port)
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

  def play(pid) do
    GenServer.call(pid, :play)
  end

  def pause(pid) do
    GenServer.call(pid, :pause)
  end

  def setup(pid) do
    GenServer.call(pid, :setup)
  end

  def teardown(pid) do
    stop_server(pid)
  end

  def stop(pid) do
    stop_server(pid)
  end

  defp stop_server(pid) do
    GenServer.call(pid, :teardown)
    GenServer.call(pid, :stop)
  end

  def terminate(_reason, _state) do
    IO.puts("Stopped")
    :ok
  end

  def start_video_rtp_stream(socket) do
    {:ok, {_addr, _port, rtp_data}} = :gen_udp.recv(socket, 0)
    IO.puts(inspect(RTPPacketParser.parse_packet(rtp_data)))
    start_video_rtp_stream(socket)
  end

  def start_video_rtcp_stream(socket) do
    :gen_udp.recv(socket, 0)
    IO.puts("video rtcp streamer: recvd rtcp packet")
    start_video_rtcp_stream(socket)
  end

  def start_audio_rtp_stream(socket) do
    {:ok, {_addr, _port, rtp_data}} = :gen_udp.recv(socket, 0)
    IO.puts("audio rtp streamer: #{inspect(rtp_data)}")
    start_audio_rtp_stream(socket)
  end

  def start_audio_rtcp_stream(socket) do
    :gen_udp.recv(socket, 0)
    IO.puts("audio rtcp streamer: recvd rtcp packet")
    start_audio_rtcp_stream(socket)
  end
end
