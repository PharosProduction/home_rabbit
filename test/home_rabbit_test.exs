defmodule HomeRabbitTest do
  use ExUnit.Case
  doctest HomeRabbit

  test "greets the world" do
    assert HomeRabbit.hello() == :world
  end
end
