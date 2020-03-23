defmodule Hadean.RTSPStreamer do
  alias Hadean.RTSPConnection

  def main(_args) do
    socket = RTSPConnection.connect({3, 84, 6, 190})
    RTSPConnection.send(socket, :options)
    session = RTSPConnection.send(socket, :describe)
    _response = RTSPConnection.send(socket, :setup, session)
    response = RTSPConnection.send(socket, :play, session)
    IO.puts(inspect(response))
  end
end
