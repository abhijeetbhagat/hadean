defmodule Hadean.Parsers.SetupResponseParser do
  def parse_server_ports(response) do
    response
    |> String.split("\r\n")
    |> Enum.find(fn x -> String.starts_with?(x, "Transport") end)
    |> String.split(";")
    |> Enum.find(fn x -> String.starts_with?(x, "server_port") end)
    |> String.split("=")
    |> Enum.at(1)
    |> String.split("-")
    |> Enum.map(fn x -> String.to_integer(x) end)
    |> List.to_tuple()
  end
end
