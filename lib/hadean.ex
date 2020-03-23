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
  end
end
