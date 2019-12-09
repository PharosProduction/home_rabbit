defmodule HomeRabbit.Configuration.ExchangeBuilder do
  alias AMQP.Basic

  @spec direct(
          exchange :: Basic.exchange(),
          queues :: list(QueueBuilder.direct_queue_configuration())
        ) :: term
  defmacro direct(exchange, queues) do
    quote do
      import HomeRabbit.Configuration.QueueBuilder, only: [queue: 2]
      {unquote(exchange), :direct, unquote(queues)} |> HomeRabbit.Configuration.ExchangeBuilder.put_new_config()
    end
  end

  @spec topic(
          exchange :: Basic.exchange(),
          queues :: list(QueueBuilder.direct_queue_configuration())
        ) :: term
  defmacro topic(exchange, queues) do
    quote do
      import HomeRabbit.Configuration.QueueBuilder, only: [queue: 2]
      {unquote(exchange), :topic, unquote(queues)} |> HomeRabbit.Configuration.ExchangeBuilder.put_new_config()
    end
  end

  @spec fanout(
          exchange :: Basic.exchange(),
          queues :: list(QueueBuilder.fanout_queue_configuration())
        ) :: term
  defmacro fanout(exchange, queues) do
    quote do
      import HomeRabbit.Configuration.QueueBuilder, only: [queue: 1]
      {unquote(exchange), :fanout, unquote(queues)} |> HomeRabbit.Configuration.ExchangeBuilder.put_new_config()
    end
  end

  @spec headers(
          exchange :: Basic.exchange(),
          queues :: list(QueueBuilder.headers_queue_configuration())
        ) :: term
  defmacro headers(exchange, queues) do
    quote do
      import HomeRabbit.Configuration.QueueBuilder, only: [queue: 3]
      {unquote(exchange), :headers, unquote(queues)} |> HomeRabbit.Configuration.ExchangeBuilder.put_new_config()
    end
  end

  def put_new_config(new) do
      old = Application.get_env(:home_rabbit, :exchanges, [])
      Application.put_env(:home_rabbit, :exchanges, [new | old])
  end
end
