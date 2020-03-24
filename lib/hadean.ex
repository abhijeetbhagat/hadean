defmodule Hadean.RTSPStreamer do
  alias Hadean.RTSPConnection

  def main(_args) do
    {:ok, pid} =
      RTSPConnection.start_link([
        "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov",
        'wowzaec2demo.streamlock.net',
        554
      ])

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
