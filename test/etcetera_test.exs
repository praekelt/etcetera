defmodule EtceteraTest do
  use ExUnit.Case
  doctest Etcetera

  test "greets the world" do
    assert Etcetera.hello() == :world
  end
end
