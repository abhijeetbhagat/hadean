defmodule HadeanTest do
  use ExUnit.Case
  alias Hadean.Parsers.ExGolombDecoder

  test "exp golomb decoding" do
    assert elem(ExGolombDecoder.read_ue(<<1::1>>), 0) == 0
    assert elem(ExGolombDecoder.read_ue(<<0::1, 1::1, 0::1>>), 0) == 1
    assert elem(ExGolombDecoder.read_ue(<<0::1, 0::1, 0::1, 1::1, 0::1, 0::1, 0::1>>), 0) == 7
    assert elem(ExGolombDecoder.read_ue(<<0::1, 0::1, 0::1, 1::1, 0::1, 0::1, 1::1>>), 0) == 8
  end
end
