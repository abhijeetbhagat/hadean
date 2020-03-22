defmodule HadeanTest do
  use ExUnit.Case
  doctest Hadean

  test "greets the world" do
    assert Hadean.hello() == :world
  end
end
