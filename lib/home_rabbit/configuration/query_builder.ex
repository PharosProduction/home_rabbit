defmodule HomeRabbit.Configuration.QueueBuilder do
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

