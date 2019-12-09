defmodule HomeRabbit.Configuration.QueueBuilder do
  alias AMQP.Basic
  @type x_match :: :any | :all
  @type x_match_arguments :: {key :: String.t(), value :: term}
  @type fanout_queue_configuration :: Basic.queue()
  @type direct_queue_configuration :: {queue :: Basic.queue(), routing_key :: Basic.routing_key()}
  @type topic_queue_configuration :: {queue :: Basic.queue(), routing_key :: Basic.routing_key()}

  @typedoc """
    {"x-match", "any"} | {"x-match", "all"}
  """
  @type x_match_configuration :: {String.t(), String.t()}
  @type headers_queue_configuration ::
          {queue :: Basic.queue(), arguments :: x_match_arguments,
           x_match :: x_match_configuration}

  @spec queue(queue :: Basic.queue()) :: fanout_queue_configuration
  def queue(queue) do
    queue
  end

  @spec queue(queue :: Basic.queue(), key :: Basic.routing_key()) ::
          direct_queue_configuration | topic_queue_configuration
  def queue(queue, key) do
    {queue, key}
  end

  @spec queue(queue :: Basic.queue(), match :: :any, arguments :: x_match_arguments) ::
          headers_queue_configuration
  def queue(queue, :any, arguments) do
    {queue, arguments, {"x-match", "any"}}
  end

  @spec queue(queue :: Basic.queue(), match :: :all, arguments :: x_match_arguments) ::
          headers_queue_configuration
  def queue(queue, :all, arguments) do
    {queue, arguments, {"x-match", "all"}}
  end
end
