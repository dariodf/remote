defmodule RemoteTest do
  use ExUnit.Case
  doctest Remote

  test "greets the world" do
    assert Remote.hello() == :world
  end
end
