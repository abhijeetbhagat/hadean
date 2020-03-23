defmodule Hadean.RTSPStreamer do
  alias Hadean.RTSPConnection

  def main(_args) do
    RTSPConnection.start_link([
      "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov",
      'wowzaec2demo.streamlock.net',
      554
    ])

    RTSPConnection.connect()
    RTSPConnection.options()
    RTSPConnection.describe()
    RTSPConnection.setup()
    RTSPConnection.play()
  end
end
