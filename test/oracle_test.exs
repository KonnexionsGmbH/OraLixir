defmodule OracleTest do
  use ExUnit.Case
  doctest Oracle

  test "greets the world" do
    assert Oracle.hello() == :world
  end
end
