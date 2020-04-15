defmodule Hadean.Commands.RTSPCommandCreator do
  use GenServer
  alias Hadean.Commands.Describe
  alias Hadean.Commands.Play

  def init({url, agent}) do
    {:ok, %{url: url, agent: agent, cseq_num: 1, session_id: nil}}
  end

  def start_link({url, agent}) do
    GenServer.start_link(__MODULE__, {url, agent}, name: __MODULE__)
  end

  def handle_call(:describe, _from, state) do
    req = Describe.create(state.url, state.cseq_num)
    {:reply, req, state |> update_cseq_num()}
  end

  def handle_play(:play, _from, state) do
    req = Play.create(state.url, state.cseq_num, state.session_id)
    {:reply, req, state |> update_cseq_num()}
  end

  def create_command(pid, :describe) do
    GenServer.call(pid, :describe)
  end

  def create_command(pid, :play) do
    GenServer.call(pid, :play)
  end

  defp update_cseq_num(state) do
    state |> Map.put(:cseq_num, state.cseq_num + 1)
  end
end
