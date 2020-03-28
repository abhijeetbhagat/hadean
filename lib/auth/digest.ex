defmodule Hadean.Authentication.Digest do
  use Agent

  defstruct username: nil,
            password: nil,
            realm: nil,
            nonce: nil,
            uri: nil,
            response: nil,
            ha1: nil

  def start_link({username, password}) do
    Agent.start_link(fn ->
      %__MODULE__{
        username: username,
        password: password
      }
    end)
  end

  def get(agent) do
    Agent.get(agent, fn state -> state end)
  end

  def update(agent, digest) do
    Agent.update(agent, fn state ->
      state
      |> Map.put(
        :ha1,
        :crypto.hash(
          :md5,
          state.username <> ":" <> digest.realm <> ":" <> state.password
        )
      )
      |> Map.put(:realm, digest.realm)
      |> Map.put(:nonce, digest.nonce)
      |> Map.put(:uri, digest.uri)
    end)
  end

  defp get_response(agent, method) do
    Agent.update(
      agent,
      fn state -> state |> Map.put(:response, calc_response(state, method)) end
    )

    Agent.get(agent, fn state -> state end)
  end

  defp calc_response(state, method) do
    ha2 = :crypto.hash(:md5, method <> ":" <> state.uri)
    :crypto.hash(:md5, state.ha1 <> ":" <> ha2) |> Base.encode16()
  end

  def get_str_rep(agent, method) do
    digest = get_response(agent, method)

    "Authentication: Digest username=\"#{digest.username}\", realm=\"#{digest.realm}\", nonce=\"#{
      digest.nonce
    }\", uri=\"#{digest.uri}\", response=\"#{digest.response}\""
  end

  def stop(agent) do
    Agent.stop(agent)
  end
end
