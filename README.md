# Hadean

```elixir
{:ok, pid} =
  RTSPConnection.start_link({
    "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov",
    :udp
  })

RTSPConnection.connect(pid, :all)

packet_processor = spawn(fn -> packet_processor() end)
RTSPConnection.attach_packet_processor(pid, packet_processor)

RTSPConnection.play(pid)

loop()
...

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
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hadean` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hadean, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/hadean](https://hexdocs.pm/hadean).

