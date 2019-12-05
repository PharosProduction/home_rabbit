defmodule HomeRabbit.Exchange do
  defmacro direct(exchange, queues) do
    quote do
      import HomeRabbit.Utils, only: [queue: 2]
      {unquote(exchange), :direct, unquote(queues)}
    end
  end

  defmacro topic(exchange, queues) do
    quote do
      import HomeRabbit.Utils, only: [queue: 2]
      {unquote(exchange), :topic, unquote(queues)}
    end
  end

  defmacro fanout(exchange, queues) do
    quote do
      import HomeRabbit.Utils, only: [queue: 1]
      {unquote(exchange), :fanout, unquote(queues)}
    end
  end

  defmacro headers(exchange, queues) do
    quote do
      import HomeRabbit.Utils, only: [queue: 3]
      {unquote(exchange), :headers, unquote(queues)}
    end
  end
end

defmodule HomeRabbit.Utils do
  def queue(queue) do
    queue
  end

  def queue(queue, routing_key: key) do
    {queue, key}
  end

  def queue(queue, :any, arguments: args) do
    {queue, args, {"x-match", "any"}}
  end

  def queue(queue, :all, arguments: args) do
    {queue, args, {"x-match", "all"}}
  end
end
