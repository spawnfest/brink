defmodule BrinkTest do
  use ExUnit.Case
  doctest Brink

  test "greets the world" do
    assert Brink.hello() == :world
  end
end
