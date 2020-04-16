defmodule Hadean.Commands.RTSPCommandCreator do
  use GenServer
  alias Hadean.Commands.Describe
  alias Hadean.Commands.Play
  alias Hadean.Commands.Setup
  alias Hadean.Commands.Pause
  alias Hadean.Commands.Teardown
  alias Hadean.Commands.Options

  def init({url, agent}) do
    # session id comes from the DESCRIBE response
    {:ok, %{url: url, agent: agent, cseq_num: 1, session_id: nil}}
  end

  def start_link({url, agent}) do
    GenServer.start_link(__MODULE__, {url, agent}, name: __MODULE__)
  end

  def handle_call(:options, _from, state) do
    req = Options.create(state.url, state.cseq_num)
    {:reply, req, state |> update_cseq_num()}
  end

  def handle_call(:describe, _from, state) do
    req = Describe.create(state.url, state.cseq_num)
    {:reply, req, state |> update_cseq_num()}
  end

  def handle_call(:play, _from, state) do
    req = Play.create(state.url, state.cseq_num, state.session)
    {:reply, req, state |> update_cseq_num()}
  end

  def handle_call({:setup, track_id, rtp_port, rtcp_port}, _from, state) do
    req = Setup.create(state.url, state.cseq_num, state.session, track_id, rtp_port, rtcp_port)
    {:reply, req, state |> update_cseq_num()}
  end

  def handle_call({:setup, track_id}, _from, state) do
    req = Setup.create(state.url, state.cseq_num, state.session, track_id)
    {:reply, req, state |> update_cseq_num()}
  end

  def handle_call(:pause, _from, state) do
    req = Pause.create(state.url, state.cseq_num, state.session)
    {:reply, req, state |> update_cseq_num()}
  end

  def handle_call(:teardown, _from, state) do
    req = Teardown.create(state.url, state.cseq_num, state.session)
    {:reply, req, state |> update_cseq_num()}
  end

  def handle_call({:set_session, session_id}, _from, state) do
    state = state |> Map.put(:session, session_id)
    {:reply, :ok, state}
  end

  def create_command(pid, :describe) do
    GenServer.call(pid, :describe)
  end

  def create_command(pid, {:setup, track_id, rtp_port, rtcp_port}) do
    GenServer.call(pid, {:setup, track_id, rtp_port, rtcp_port})
  end

  def create_command(pid, {:setup, track_id}) do
    GenServer.call(pid, {:setup, track_id})
  end

  def create_command(pid, :play) do
    GenServer.call(pid, :play)
  end

  def set_session(pid, {:set_session, session_id}) do
    GenServer.call(pid, {:set_session, session_id})
  end

  defp update_cseq_num(state) do
    state |> Map.put(:cseq_num, state.cseq_num + 1)
  end
end
