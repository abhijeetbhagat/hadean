defmodule Hadean.RTSPStreamer do
  alias Hadean.RTSPConnection

  def main(_args) do
    socket = RTSPConnection.connect({3, 84, 6, 190})
    RTSPConnection.send(socket, :options)
    sdp = RTSPConnection.send(socket, :describe)
    IO.puts(inspect(sdp))
  end
end
