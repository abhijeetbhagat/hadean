defmodule Hadean.RTSPStreamer do
  alias Hadean.RTSPConnection
  alias Hadean.RTSPOverUDPConnection

  def main(_args) do
    start_udp_conn()
  end

  def start_udp_conn() do
    {:ok, pid} =
      RTSPOverUDPConnection.start_link(
        "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov"
      )

    RTSPOverUDPConnection.connect(pid)
    RTSPOverUDPConnection.options(pid)
    RTSPOverUDPConnection.describe(pid)
    RTSPOverUDPConnection.setup(pid)
    RTSPOverUDPConnection.play(pid)

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
      RTSPConnection.start_link(
        "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov"
      )

    RTSPConnection.connect(pid)
    RTSPConnection.options(pid)
    RTSPConnection.describe(pid)
    RTSPConnection.setup(pid)
    RTSPConnection.play(pid)
    IO.puts("Spawned play ...")

    # Task.start_link(fn -> RTSPConnection.play(pid) end)

    IO.puts("Sleeing for a while ...")
    :timer.sleep(5000)
    IO.puts("Ok just woke up...")
    IO.puts("Bout to kill that stream...")

    RTSPConnection.stop(pid)

    loop()
  end

  def loop() do
    receive do
      _ -> :ok
    end
  end
end
