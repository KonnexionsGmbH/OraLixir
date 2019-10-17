defmodule OraLixirTest do
  use ExUnit.Case
  # doctest OraLixir

  test "connect to oracle" do
    assert OraLixir.start_link([]) == :world
  end
end
