defmodule TogglerCliTest do
  use ExUnit.Case
  doctest TogglerCli

  test "greets the world" do
    assert TogglerCli.hello() == :world
  end
end
