defmodule OraLixirTest do
  use ExUnit.Case
  doctest Oracle

  test "greets the world" do
    assert OraLixir.hello() == :world
  end
end
