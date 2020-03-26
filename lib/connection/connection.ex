use Bitwise

defmodule Hadean.RTSPConnection do
  use GenServer
  alias Hadean.Parsers.RTPPacketParser
  alias Hadean.Parsers.SDPParser
  alias Hadean.Parsers.UrlParser
  alias Hadean.Commands.Describe
  alias Hadean.Commands.Setup
  alias Hadean.Commands.Pause
  alias Hadean.Commands.Options
  alias Hadean.Commands.Teardown
  alias Hadean.Commands.Play

  defstruct url: nil,
            server: nil,
            port: 0,
            socket: nil,
            session: 0,
            # interleaved or UDP
            mode: :interleaved,
            cseq_num: 0,
            streamer_pid: 0

  def init([url, server, port]) do
    state = %__MODULE__{
      url: url,
      server: server,
      port: port
    }

    {:ok, state}
  end

  def init(base_url) do
    {server, port} = UrlParser.parse(base_url)

    state = %__MODULE__{
      url: base_url,
      server: server,
      port: port
    }

    {:ok, state, 10_000_000}
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def handle_call(:connect, _from, state) do
    socket =
      case :gen_tcp.connect(state.server, state.port, [:binary, active: false, packet: :raw]) do
        {:ok, socket} -> socket
        {:error, reason} -> raise reason
      end

    {:reply, state, state |> Map.put(:socket, socket)}
  end

  def handle_call(:options, _from, state) do
    :gen_tcp.send(
      state.socket,
      Options.create(state.url, state.cseq_num)
    )

    case :gen_tcp.recv(state.socket, 0) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise reason
    end

    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:setup, _from, state) do
    state =
      if state.context.audio_track != nil do
        handle(state.context.audio_track.id, state)
      end

    state =
      if state.context.video_track != nil do
        handle(state.context.video_track.id, state)
      end

    {:reply, state, state}
  end

  def handle_call(:describe, _from, state) do
    :gen_tcp.send(
      state.socket,
      Describe.create(state.url, state.cseq_num)
    )

    response =
      case :gen_tcp.recv(state.socket, 0) do
        {:ok, bytes} -> bytes
        {:error, reason} -> raise reason
      end

    context = SDPParser.parse_sdp(response)

    {:reply, state,
     state
     |> Map.put(:context, context)
     |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:play, _from, state) do
    :gen_tcp.send(
      state.socket,
      Play.create(state.url, state.cseq_num, state.session)
    )

    # TODO abhi: spawn as a Task under supervision
    streamer_pid = spawn(__MODULE__, :start, [state.socket])
    # Task.start(fn -> start(state.socket) end)
    {:reply, state,
     state |> Map.put(:streamer_pid, streamer_pid) |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:pause, _from, state) do
    IO.puts("sending pause ...")

    :gen_tcp.send(
      state.socket,
      Pause.create(state.url, state.cseq_num, state.context.session)
    )

    {:reply, state, state |> Map.put(:cseq_num, state.cseq_num + 1)}
  end

  def handle_call(:teardown, _from, state) do
    :gen_tcp.send(
      state.socket,
      Teardown.create(state.url, state.cseq_num, state.context.session)
    )

    # stop streaming process
    Process.exit(state.streamer_pid, :shutdown)

    :gen_tcp.close(state.socket)
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, state}
  end

  def handle(id, state) do
    :gen_tcp.send(
      state.socket,
      Setup.create(
        state.url,
        state.cseq_num,
        state.context.session,
        id
      )
    )

    _response = :gen_tcp.recv(state.socket, 0)
    state |> Map.put(:cseq_num, state.cseq_num + 1)
  end

  def connect(pid) do
    GenServer.call(pid, :connect)
  end

  def options(pid) do
    GenServer.call(pid, :options)
  end

  def describe(pid) do
    GenServer.call(pid, :describe)
  end

  # TODO abhi: figure out a way to use regex

  def play(pid) do
    GenServer.call(pid, :play)
  end

  def pause(pid) do
    GenServer.call(pid, :pause)
  end

  def setup(pid) do
    GenServer.call(pid, :setup)
  end

  def teardown(pid) do
    stop_server(pid)
  end

  def stop(pid) do
    stop_server(pid)
  end

  defp stop_server(pid) do
    GenServer.call(pid, :teardown)
    GenServer.call(pid, :stop)
  end

  def terminate(_reason, _state) do
    IO.puts("Stopped")
    :ok
  end

  def start(socket) do
    {:ok,
     <<
       magic::integer-8,
       _channel::integer-8,
       len::integer-16
     >>} = :gen_tcp.recv(socket, 4)

    # if magic is '$', then it is start of the rtp data
    if magic == 0x24 do
      {:ok, rtp_data} = :gen_tcp.recv(socket, len)
      IO.puts(inspect(RTPPacketParser.parse_packet(rtp_data)))
    end

    start(socket)
  end
end
