defmodule Hadean.Parsers.SDPParser do
  def parse_sdp(data) do
    String.split(data, "\r\n")
    |> Enum.find(fn line -> String.starts_with?(line, "Session") end)
    |> String.split(";")
    |> Enum.at(0)
    |> String.split(" ")
    |> Enum.at(1)
  end
end
