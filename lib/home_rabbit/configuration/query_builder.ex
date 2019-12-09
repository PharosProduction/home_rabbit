defmodule HomeRabbit.Configuration.QueueBuilder do
  alias AMQP.Basic
  @type x_match :: :any | :all
  @type x_match_arguments :: {key :: String.t(), value :: term}
  @type fanout_queue_configuration :: Basic.queue()
  @type direct_queue_configuration :: {queue :: Basic.queue(), routing_key :: Basic.routing_key()}
  @type topic_queue_configuration :: {queue :: Basic.queue(), routing_key :: Basic.routing_key()}

  @type headers_queue_configuration ::
          {queue :: Basic.queue(), x_match :: x_match, arguments :: x_match_arguments}

  def queue({queue, :any, arguments: args}) do
    {queue, args, {"x-match", "any"}}
  end

  def queue({queue, :all, arguments: args}) do
    {queue, args, {"x-match", "all"}}
  end
end
