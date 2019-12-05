defmodule HomeRabbit.Configuration.ExchangeBuilder do
  defmacro direct(exchange, queues) do
    quote do
      import HomeRabbit.Configuration.QueueBuilder, only: [queue: 2]
      {unquote(exchange), :direct, unquote(queues)}
    end
  end

  defmacro topic(exchange, queues) do
    quote do
      import HomeRabbit.Configuration.QueueBuilder, only: [queue: 2]
      {unquote(exchange), :topic, unquote(queues)}
    end
  end

  defmacro fanout(exchange, queues) do
    quote do
      import HomeRabbit.Configuration.QueueBuilder, only: [queue: 1]
      {unquote(exchange), :fanout, unquote(queues)}
    end
  end

  defmacro headers(exchange, queues) do
    quote do
      import HomeRabbit.Configuration.QueueBuilder, only: [queue: 3]
      {unquote(exchange), :headers, unquote(queues)}
    end
  end
end
