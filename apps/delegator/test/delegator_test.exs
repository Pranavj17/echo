defmodule DelegatorTest do
  use ExUnit.Case
  doctest Delegator

  test "greets the world" do
    assert Delegator.hello() == :world
  end
end
