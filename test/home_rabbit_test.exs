defmodule HomeRabbitTest do
  use ExUnit.Case
  doctest HomeRabbit.Exchange.Direct
  doctest HomeRabbit.Exchange.Fanout
  doctest HomeRabbit.Exchange.Headers
  doctest HomeRabbit.Exchange.Topic
  doctest HomeRabbit.Observer

  test "greets the world" do
  end
end
