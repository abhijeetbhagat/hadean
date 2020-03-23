use Bitwise

defmodule Hadean.RTSPConnection do
  def connect(url) do
    socket =
      case :gen_tcp.connect(url, 554, [:binary, active: false, packet: :raw]) do
        {:ok, socket} -> socket
        {:error, reason} -> raise reason
      end

    socket
  end

  def send(socket, :options) do
    :gen_tcp.send(
      socket,
      "OPTIONS rtsp://wowzaec2demo.streamlock.net:554/vod/mp4:BigBuckBunny_115k.mov RTSP/1.0\r\nCSeq: 2\r\nUser-Agent: hadean\r\n\r\n"
    )

    case :gen_tcp.recv(socket, 0) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise reason
    end
  end

  def send(socket, :describe) do
    :gen_tcp.send(
      socket,
      "DESCRIBE rtsp://wowzaec2demo.streamlock.net:554/vod/mp4:BigBuckBunny_115k.mov RTSP/1.0\r\nCSeq: 3\r\nAccept: application/sdp\r\n\r\n"
    )

    response =
      case :gen_tcp.recv(socket, 0) do
        {:ok, bytes} -> bytes
        {:error, reason} -> raise reason
      end

    session = parse_sdp(response)
    session
  end

  # TODO abhi: figure out a way to use regex

  def send(socket, :play, session) do
    :gen_tcp.send(
      socket,
      "PLAY rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov/trackID=2 RTSP/1.0\r\nCSeq: 5\r\nUser-Agent: hadean\r\nSession: #{
        session
      }\r\nRange: npt=0.000-\r\n\r\n"
    )

    start(socket)
  end

  def send(socket, :setup, session) do
    :gen_tcp.send(
      socket,
      "SETUP rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov/trackID=2 RTSP/1.0\r\nCSeq: 4\r\nUser-Agent: hadean\r\nTransport: RTP/AVP;unicast;interleaved=0-1\r\nSession: #{
        session
      }\r\n\r\n"
    )

    response = :gen_tcp.recv(socket, 0)
    response
  end

  def start(socket) do
    {:ok,
     <<
       packet_header::integer-8,
       _::integer-8,
       len::integer-16
     >>} = :gen_tcp.recv(socket, 4)

    # if packet_header is '$', then it is start of the rtp data
    if packet_header == 0x24 do
      {:ok, rtp_data} = :gen_tcp.recv(socket, len)
      IO.puts(inspect(parse_packet(rtp_data)))
    end

    start(socket)
  end

  @spec parse_sdp(binary) :: any
  def parse_sdp(response) do
    String.split(response, "\r\n")
    |> Enum.find(fn line -> String.starts_with?(line, "Session") end)
    |> String.split(";")
    |> Enum.at(0)
    |> String.split(" ")
    |> Enum.at(1)
  end

  def parse_packet(rtp_data) do
    <<
      packet_header::integer-8,
      marker_payload_type::integer-8,
      seq_num::integer-16,
      timestamp::integer-32,
      ssrc::integer-32,
      _rest::binary
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
      ssrc: ssrc
    }
  end
end
