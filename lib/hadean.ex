defmodule Hadean.RTSPStreamer do
  alias Hadean.RTSPConnection

  def main(_args) do
    start_udp_conn()
  end

  def start_udp_conn() do
    {:ok, pid} =
      RTSPConnection.start_link({
        "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov",
        :udp
      })

    RTSPConnection.connect(pid, :all)

    packet_processor = spawn(fn -> packet_processor() end)
    RTSPConnection.attach_packet_processor(pid, packet_processor)

    RTSPConnection.play(pid)

    _ = """
      IO.puts("Spawned play ...")

    # Task.start_link(fn -> RTSPConnection.play(pid) end)

    IO.puts("Sleeing for a while ...")
    :timer.sleep(5000)
    IO.puts("Ok just woke up...")
    IO.puts("Bout to kill that stream...")

    RTSPConnection.stop(pid)
    """

    loop()
  end

  def start_tcp_conn() do
    {:ok, pid} =
      RTSPConnection.start_link({
        "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov",
        :tcp
      })

    RTSPConnection.connect(pid, :video)

    packet_processor = spawn(fn -> packet_processor() end)
    RTSPConnection.attach_packet_processor(pid, packet_processor)
    RTSPConnection.play(pid)
    IO.puts("Spawned play ...")

    # Task.start_link(fn -> RTSPConnection.play(pid) end)

    _ = """
    IO.puts("Sleeing for a while ...")
    :timer.sleep(5000)
    IO.puts("Ok just woke up...")
    IO.puts("Bout to kill that stream...")

    RTSPConnection.stop(pid)
    """

    loop()
  end

  defp packet_processor() do
    receive do
      {:audio, _packet} ->
        IO.puts("audio packet received")

      {:video, packet} ->
        IO.puts("frame_type: #{inspect(packet.frame_type)}")

      {:unknown, _} ->
        IO.puts("Unknown packet")
    end

    packet_processor()
  end

  def loop() do
    receive do
      _ -> :ok
    end
  end
end
