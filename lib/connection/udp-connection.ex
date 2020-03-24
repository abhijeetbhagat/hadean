use Bitwise

defmodule Hadean.RTSPOverConnection do
  use GenServer

  defstruct url: nil,
            server: nil,
            port: 0,
            rtsp_socket: nil,
            video_rtp_socket: nil,
            video_rtcp_socket: nil,
            video_rtp_port: 0,
            video_rtcp_port: 0,
            session: 0,
            # interleaved or UDP
            mode: :interleaved,
            cseq_num: 0,
            video_rtp_streamer_pid: 0,
            video_rtcp_streamer_pid: 0

  def init([url, server, port]) do
    state = %__MODULE__{
      url: url,
      server: server,
      port: port
    }

    {:ok, state}
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
    rtp_port = 678_901
    rtcp_port = 678_902

    :gen_tcp.send(
      state.rtsp_socket,
      "SETUP #{state.url}/trackID=2 RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nTransport: RTP/AVP;unicast;client_port=#{
        rtp_port
      }-#{rtcp_port}\r\nSession: #{state.session}\r\n\r\n"
    )

    response = :gen_tcp.recv(state.socket, 0)

    [server_rtp_port, server_rtcp_port] =
      response
      |> String.split("\r\n")
      |> Enum.find(fn x -> String.starts_with?(x, "Transport") end)
      |> String.split(";")
      |> Enum.find(fn x -> String.starts_with?(x, "server_port") end)
      |> String.split("=")
      |> Enum.at(1)
      |> String.split("-")
      |> Enum.map(fn x -> String.to_integer(x) end)

    video_rtp_socket = :gen_udp.open(server_rtp_port)
    video_rtcp_socket = :gen_udp.open(server_rtcp_port)

    state =
      state
      |> Map.put(:video_rtp_socket, video_rtp_socket)
      |> Map.put(:video_rtcp_socket, video_rtcp_socket)

    :gen_udp.send(state.video_rtp_socket, state.server, server_rtp_port, "deadface")
    :gen_udp.send(state.video_rtcp_socket, state.server, server_rtcp_port, "")

    :gen_udp.send(state.video_rtp_socket, state.server, server_rtp_port, "deadface")
    :gen_udp.send(state.video_rtcp_socket, state.server, server_rtcp_port, "")

    {:reply, state,
     state
     |> Map.put(:cseq_num, state.cseq_num + 1)
     |> Map.put(:video_rtp_port, server_rtp_port)
     |> Map.put(:video_rtcp_port, server_rtcp_port)}
  end

  def handle_call(:describe, _from, state) do
    :gen_tcp.send(
      state.socket,
      "DESCRIBE #{state.url} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nAccept: application/sdp\r\n\r\n"
    )

    response =
      case :gen_tcp.recv(state.rtsp_socket, 0) do
        {:ok, bytes} -> bytes
        {:error, reason} -> raise reason
      end

    session = parse_sdp(response)

    {:reply, state,
     state
     |> Map.put(:session, session)
     |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:play, _from, state) do
    :gen_tcp.send(
      state.rtsp_socket,
      "PLAY #{state.url}/trackID=2 RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nSession: #{
        state.session
      }\r\nRange: npt=0.000-\r\n\r\n"
    )

    # TODO abhi: spawn as a Task under supervision
    video_rtp_streamer_pid = spawn(__MODULE__, :start_video_rtp_stream, [state.video_rtp_socket])

    video_rtcp_streamer_pid =
      spawn(__MODULE__, :start_video_rtcp_stream, [state.video_rtcp_socket])

    # Task.start(fn -> start(state.socket) end)
    {:reply, state,
     state
     |> Map.put(:video_rtp_streamer_pid, video_rtp_streamer_pid)
     |> Map.put(:video_rtcp_streamer_pid, video_rtcp_streamer_pid)
     |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:pause, _from, state) do
    IO.puts("sending pause ...")

    :gen_tcp.send(
      state.rtsp_socket,
      "PAUSE #{state.url} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nSession: #{
        state.session
      }\r\n\r\n"
    )

    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:teardown, _from, state) do
    :gen_tcp.send(
      state.rtsp_socket,
      "TEARDOWN #{state.url} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nSession: #{
        state.session
      }\r\n\r\n"
    )

    # stop streaming process
    Process.exit(state.video_rtp_streamer_pid, :shutdown)
    Process.exit(state.video_rtcp_streamer_pid, :shutdown)

    :gen_tcp.close(state.socket)
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, state}
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
    :gen_udp.recv(socket, 0)
    IO.puts("recvd rtp packet")
    start_video_rtp_stream(socket)
  end

  def start_video_rtcp_stream(socket) do
    :gen_udp.recv(socket, 0)
    IO.puts("recvd rtcp packet")
    start_video_rtcp_stream(socket)
  end

  @spec parse_sdp(binary) :: any
  defp parse_sdp(response) do
    String.split(response, "\r\n")
    |> Enum.find(fn line -> String.starts_with?(line, "Session") end)
    |> String.split(";")
    |> Enum.at(0)
    |> String.split(" ")
    |> Enum.at(1)
  end

  defp parse_packet(rtp_data) do
    <<
      packet_header::integer-8,
      marker_payload_type::integer-8,
      seq_num::integer-16,
      timestamp::integer-32,
      ssrc::integer-32,
      rest::binary
    >> = rtp_data

    version =
      case packet_header &&& 0x80 do
        0 -> 1
        _ -> 2
      end

    padding = (packet_header &&& 0x20) > 0
    extension = (packet_header &&& 0x10) > 0
    cc = packet_header &&& 0xF
    marker = (marker_payload_type &&& 0x80) > 0
    payload_type = marker_payload_type &&& 0x7F

    %Hadean.Packet.RTPPacket{
      version: version,
      padding: padding,
      extension: extension,
      cc: cc,
      marker: marker,
      payload_type: payload_type,
      seq_num: seq_num,
      timestamp: timestamp,
      ssrc: ssrc,
      nal_data: rest
    }
  end
end
