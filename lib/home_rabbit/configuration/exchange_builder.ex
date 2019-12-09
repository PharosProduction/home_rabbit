defmodule HomeRabbit.Configuration.ExchangeBuilder do
  alias AMQP.Basic
  alias HomeRabbit.Configuration.QueueBuilder

  @spec direct(
          exchange :: Basic.exchange(),
          queues :: list(QueueBuilder.direct_queue_configuration())
        ) ::
          {exchange :: Basic.exchange(), :direct, list(QueueBuilder.direct_queue_configuration())}
  def direct(exchange, queues) do
    {exchange, :direct, queues}
  end

  @spec topic(
          exchange :: Basic.exchange(),
          queues :: list(QueueBuilder.direct_queue_configuration())
        ) ::
          {exchange :: Basic.exchange(), :topic, list(QueueBuilder.direct_queue_configuration())}
  def topic(exchange, queues) do
    {exchange, :topic, queues}
  end

  @spec fanout(
          exchange :: Basic.exchange(),
          queues :: list(QueueBuilder.fanout_queue_configuration())
        ) ::
          {exchange :: Basic.exchange(), :fanout, list(QueueBuilder.fanout_queue_configuration())}
  def fanout(exchange, queues) do
    {exchange, :fanout, queues}
  end

  @spec headers(
          exchange :: Basic.exchange(),
          queues :: list(QueueBuilder.headers_queue_configuration())
        ) ::
          {exchange :: Basic.exchange(), :headers,
           queues :: list(QueueBuilder.headers_queue_configuration())}
  def headers(exchange, queues) do
    {exchange, :headers, queues |> Enum.map(&QueueBuilder.queue/1)}
  end
end
