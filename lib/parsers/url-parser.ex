defmodule Hadean.Parsers.UrlParser do
  def parse(base_url) do
    server =
      base_url
      |> String.split("//")
      |> Enum.at(1)
      |> String.split("/")
      |> Enum.at(0)

    get_server_port(String.split(server, ":"))
  end

  defp get_server_port([server]) do
    {String.to_charlist(server), Application.fetch_env!(:hadean, :default_rtsp_port)}
  end

  defp get_server_port([server, port]) do
    {String.to_charlist(server), port}
  end
end
