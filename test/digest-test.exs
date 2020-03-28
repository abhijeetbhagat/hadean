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

    state = Digest.get_response(pid)
    assert state.response != nil
    state = Digest.get_response(pid)
    assert state.response != nil
    s = Digest.get_str_rep(pid)
    IO.puts(inspect(s))
  end
end
