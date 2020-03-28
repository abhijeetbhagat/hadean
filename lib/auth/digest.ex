defmodule Hadean.Authentication.Digest do
  use Agent

  defstruct username: nil,
            password: nil,
            realm: nil,
            nonce: nil,
            uri: nil,
            response: nil

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
      |> Map.put(:realm, digest.realm)
      |> Map.put(:nonce, digest.nonce)
      |> Map.put(:uri, digest.uri)
    end)
  end

  def get_response(agent) do
    state = Agent.get(agent, fn state -> state end)

    case state.response do
      nil ->
        Agent.update(
          agent,
          fn state -> state |> Map.put(:response, calc_response(state)) end
        )

        Agent.get(agent, fn state -> state end)

      _ ->
        state
    end
  end

  defp calc_response(state) do
    ha1 = :crypto.hash(:md5, state.username <> ":" <> state.realm <> ":" <> state.password)
    ha2 = :crypto.hash(:md5, "SETUP" <> ":" <> state.uri)
    :crypto.hash(:md5, ha1 <> ":" <> ha2) |> Base.encode16()
  end

  def get_str_rep(agent) do
    digest = Hadean.Authentication.Digest.get(agent)

    "Authentication: Digest username=\"#{digest.username}\", realm=\"#{digest.realm}\", nonce=\"#{
      digest.nonce
    }\", uri=\"#{digest.uri}\", response=\"#{digest.response}\"\r\n\r\n"
  end
end
