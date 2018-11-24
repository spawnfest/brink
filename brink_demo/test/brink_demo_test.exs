defmodule BrinkDemoTest do
  use ExUnit.Case
  doctest BrinkDemo

  test "greets the world" do
    assert BrinkDemo.hello() == :world
  end
end
