defmodule HomeRabbit.ChannelPool do
  alias HomeRabbit.ConnectionManager
  alias AMQP.{Channel, Basic, Queue, Exchange}

  import HomeRabbit.Configuration.ExchangeBuilder
  require Logger

  use GenServer

  @errors_exchange_name "errors_exchange"
  @errors_queue "errors_queue"
  @errors_exchange direct(@errors_exchange_name, [
                     queue(@errors_queue, routing_key: @errors_queue)
                   ])

  # Client
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def release_channel(channel) do
    GenServer.cast(__MODULE__, {:release_channel, channel})
  end

  def get_channel() do
    GenServer.call(__MODULE__, :get_channel)
  end

  # Server
  @impl true
  def init(_opts) do
    {:ok, con} = ConnectionManager.get_connection()
    {:ok, chan} = Channel.open(con)

    [@errors_exchange | Application.get_env(:home_rabbit, :exchanges, [])]
    |> Enum.each(&setup_exchange(chan, &1))

      # TODO: do I really need this?
    :ok = Basic.qos(chan, prefetch_count: Application.get_env(:home_rabbit, :prefetch_count, 10))

    {:ok, [chan]}
  end

  @impl true
  def handle_call(:get_channel, _from, pool) do
    if pool |> Enum.any?() do
      [chan | rest] = pool
      {:reply, {:ok, chan}, rest}
    else
      {:ok, con} = ConnectionManager.get_connection()
      {:ok, chan} = Channel.open(con)

      # TODO: do I really need this?
      :ok =
        Basic.qos(chan, prefetch_count: Application.get_env(:home_rabbit, :prefetch_count, 10))

      {:reply, {:ok, chan}, pool}
    end
  end

  @impl true
  def handle_cast({:release_channel, channel}, pool) do
    limit = Application.get_env(:home_rabbit, :max_cannels, :infinite)
    count = Enum.count(pool)
    Logger.debug("Channel limit: #{limit}")

    case limit do
      limit when limit == :infinite or limit > count ->
        Logger.debug("Channel count: #{count + 1}")
        {:noreply, [channel | pool]}

      limit when limit <= count ->
        Channel.close(channel)
        Logger.debug("Channel count: #{count}")
        {:noreply, pool}

      wrong_argument ->
        Logger.warn("Wrong configuration for :home_rabbit :max_channels: #{wrong_argument}")
        Logger.debug("Channel count: #{count + 1}")
        {:noreply, [channel | pool]}
    end
  end

  # Setup

  defp setup_exchange(chan, {exchange, type, queues}) do
    with :ok <- Exchange.declare(chan, exchange, type, durable: true) do
      Logger.debug("Exchange was declared:\nExchange: #{exchange}\nType: #{type |> inspect()}")

      case type do
        :fanout ->
          queues
          |> Enum.each(&setup_queue(chan, exchange, &1, fn -> Queue.bind(chan, &1, exchange) end))

        :topic ->
          queues
          |> Enum.each(fn {queue, key} ->
            setup_queue(chan, exchange, queue, fn ->
              Queue.bind(chan, queue, exchange, routing_key: key)
            end)
          end)

        :direct ->
          queues
          |> Enum.each(fn {queue, key} ->
            setup_queue(chan, exchange, queue, fn ->
              Queue.bind(chan, queue, exchange, routing_key: key)
            end)
          end)

        :headers ->
          queues
          |> Enum.each(fn {queue, args, x_match} ->
            setup_queue(chan, exchange, queue, fn ->
              Queue.bind(chan, queue, exchange, arguments: args ++ [x_match])
            end)
          end)
      end
    else
      {:error, reason} ->
        Logger.error("Failed exchange setup:\nExchange: #{exchange}\nReason: #{reason}")
    end
  end

  defp setup_queue(chan, exchange, queue, bind_fn) do
    with {:ok, _res} <- declare_queue(chan, queue, @errors_queue),
         :ok <- bind_fn.() do
      Logger.debug(
        "Queue was declared and bound to exchange:\nQueue: #{queue}\nExchange: #{exchange}"
      )
    else
      {:error, reason} ->
        Logger.error("Failed queue setup:\nQueue: #{queue}\nReason: #{reason}")
    end
  end

  defp declare_queue(chan, queue, error_queue_name) do
    if queue == error_queue_name do
      Queue.declare(chan, queue, durable: true)
    else
      Queue.declare(chan, queue,
        durable: true,
        arguments: [
          {"x-dead-letter-exchange", :longstr, @errors_exchange_name},
          {"x-dead-letter-routing-key", :longstr, error_queue_name}
        ]
      )
    end
  end
end
