defmodule Hadean.Parsers.DescribeResponseParser do
  alias Hadean.Authentication.Digest

  def parse(response, url) do
    case response
         |> String.split("\r\n")
         |> Enum.find(fn line -> String.starts_with?(line, "WWW-Authenticate") end) do
      nil -> :no_auth
      line -> {:auth_required, line |> to_auth(url)}
    end
  end

  defp to_auth(line, url) do
    _ = """
    WWW-Authenticate: Digest realm="Streaming Server", nonce="e539951941e259b7e69f7642cb5ea498"
    """

    [{key, val} | tail] =
      line
      |> String.split(", ")
      |> Enum.map(fn prop_val -> String.split(prop_val, "=") |> List.to_tuple() end)

    key =
      key
      |> String.split(" ")
      |> Enum.at(2)

    loop([{key, val} | tail] ++ [{"uri", url}], %Digest{})
  end

  defp loop([line | lines], digest) do
    digest =
      case line do
        {"realm", value} ->
          digest |> Map.put(:realm, value)

        {"nonce", value} ->
          digest |> Map.put(:nonce, value)

        {"opaque", value} ->
          digest |> Map.put(:opaque, value)

        {"qop", value} ->
          digest |> Map.put(:opaque, value)

        {"algorithm", value} ->
          digest |> Map.put(:opaque, value)

        {"domain", value} ->
          digest |> Map.put(:opaque, value)

        {"uri", value} ->
          digest |> Map.put(:opaque, value)
      end

    loop(lines, digest)
  end

  defp loop([], digest) do
    digest
  end
end
