defmodule HadeanTest do
  use ExUnit.Case
  alias Hadean.Authentication.Digest

  test "digest agent" do
    {:ok, pid} = Digest.start_link({"abhi", "pass"})

    Digest.update(pid, %Digest{
      realm: "streaming server",
      nonce: "e539951941e259b7e69f7642cb5ea498",
      uri: "some/uri"
    })

    state = Digest.get_str_rep(pid, "DESCRIBE")
    IO.puts(state)
    state = Digest.get_str_rep(pid, "SETUP")
    IO.puts(state)
    state = Digest.get_str_rep(pid, "SETUP")
    IO.puts(state)
  end
end
