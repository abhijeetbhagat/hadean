use Bitwise

defmodule Hadean.RTSPConnection do
  use GenServer

  defstruct url: nil,
            server: nil,
            port: 0,
            socket: nil,
            session: 0,
            # interleaved or UDP
            mode: :interleaved,
            cseq_num: 0

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
      "OPTIONS #{state.url} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\n\r\n"
    )

    case :gen_tcp.recv(state.socket, 0) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise reason
    end

    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:setup, _from, state) do
    :gen_tcp.send(
      state.socket,
      "SETUP #{state.url}/trackID=2 RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nTransport: RTP/AVP;unicast;interleaved=0-1\r\nSession: #{
        state.session
      }\r\n\r\n"
    )

    _response = :gen_tcp.recv(state.socket, 0)
    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:describe, _from, state) do
    :gen_tcp.send(
      state.socket,
      "DESCRIBE #{state.url} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nAccept: application/sdp\r\n\r\n"
    )

    response =
      case :gen_tcp.recv(state.socket, 0) do
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
      state.socket,
      "PLAY #{state.url}/trackID=2 RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nSession: #{
        state.session
      }\r\nRange: npt=0.000-\r\n\r\n"
    )

    # TODO abhi: state is as a Task under supervision
    spawn(__MODULE__, :start, [state.socket])
    # Task.start(fn -> start(state.socket) end)
    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:pause, _from, state) do
    IO.puts("sending pause ...")

    :gen_tcp.send(
      state.socket,
      "PAUSE #{state.url} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nSession: #{
        state.session
      }\r\n\r\n"
    )

    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
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

  def start(socket) do
    {:ok,
     <<
       magic::integer-8,
       _channel::integer-8,
       len::integer-16
     >>} = :gen_tcp.recv(socket, 4)

    # if magic is '$', then it is start of the rtp data
    if magic == 0x24 do
      {:ok, rtp_data} = :gen_tcp.recv(socket, len)
      IO.puts(inspect(parse_packet(rtp_data)))
    end

    start(socket)
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
