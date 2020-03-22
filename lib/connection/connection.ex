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

    case :gen_tcp.recv(socket, 0) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise reason
    end
  end

  def send(socket, :setup) do
    :gen_tcp.send(
      socket,
      "SETUP rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov RTSP/1.0\r\nCSeq: 4\r\nUser-Agent: insight\r\nTransport: RTP/AVP;unicast;interleaved=0-1\r\n\r\n"
    )
  end

  def send(socket, :play) do
    :gen_tcp.send(
      socket,
      "PLAY rtsp://184.72.239.149:554/vod/mp4:BigBuckBunny_175k.mov/trackID=2 RTSP/1.0\r\nCSeq: 5\r\nUser-Agent: insight\r\nSession: {}\r\nRange: npt=0.000-\r\n\r\n"
    )
  end
end
