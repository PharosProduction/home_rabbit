defmodule HomeRabbit.Observer do
  @moduledoc """
  Documentation for HomeRabbit.Observer

  ## Examples
  ```elixir
    iex> defmodule TestObserverExchange do
    ...>   use HomeRabbit.Exchange.Direct, exchange: "test_observer_exchange", queues: [[queue: "test_observer_queue", routing_key: "test_observer"]]
    ...>   defmessage SayHiMessage do
    ...>     def new() do
    ...>       %SayHiMessage{routing_key: "test_observer", payload: "Hello from TestObserver"}
    ...>     end
    ...>   end
    ...> end
    iex> start_supervised!(TestObserverExchange)
    iex> defmodule TestObserver do
    ...>   use HomeRabbit.Observer, queue: "test_observer_queue"
    ...>   @impl true
    ...>   def handle(message) do
    ...>     Logger.debug(message)
    ...>   end
    ...> end
    ...> start_supervised!(TestObserver)
    iex> TestObserverExchange.publish(TestObserverExchange.SayHiMessage.new())
    :ok

  ```
  """

  @callback handle(payload :: term) :: :ok | {:error, reason :: term}

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      alias HomeRabbit.{ChannelPool, Observer}
      alias AMQP.{Basic, Queue}

      require Logger

      use GenServer

      @behaviour Observer

      @queue opts[:queue]
      @queue_cache_table __MODULE__
      @max_retries opts |> Keyword.get(:max_retries, 0)

      def start_link(_opts) do
        GenServer.start_link(__MODULE__, nil, name: __MODULE__)
      end

      @impl true
      def init(_) do
        Process.flag(:trap_exit, true)
        send(self(), :connect)
        {:ok, nil}
      end

      @impl true
      def handle_info(:connect, _conn) do
        reconnect_interval = Application.get_env(:home_rabbit, :reconnect_interval, 10_000)

        with {:ok, chan} <- ChannelPool.get_channel() do
          # Get notifications when the connection goes down
          Process.monitor(chan.pid)

          # Register the GenServer process as a consumer
          {:ok, _consumer_tag} = Basic.consume(chan, @queue)

          KV.add_table(@queue_cache_table)
          Logger.debug("Observer #{__MODULE__} initialized")

          {:noreply, chan}
        else
          {:error, _} ->
            # Retry later
            Process.send_after(self(), :connect, reconnect_interval)
            {:noreply, nil}
        end
      end

      @impl true
      def handle_info({:DOWN, _, :process, _pid, reason}, chan) do
        # Stop GenServer. Will be restarted by Supervisor.
        ChannelPool.close_channel(chan)
        {:stop, {:connection_lost, reason}, nil}
      end

      # Confirmation sent by the broker after registering this process as a consumer
      @impl true
      def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, chan) do
        {:noreply, chan}
      end

      # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
      @impl true
      def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, chan) do
        {:stop, :normal, chan}
      end

      # Confirmation sent by the broker to the consumer process after a Basic.cancel
      @impl true
      def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, chan) do
        {:noreply, chan}
      end

      @impl true
      def handle_info(
            {:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}},
            chan
          ) do
        if not redelivered do
          KV.put(@max_retries, tag, @queue_cache_table)
        end

        consume(chan, tag, payload)
        {:noreply, chan}
      end

      @impl true
      def handle_info({:EXIT, _from, reason}, chan) do
        ChannelPool.release_channel(chan)

        case reason do
          :shutdown -> Logger.info("#{__MODULE__} exiting with reason: :shutdown")
          reason -> Logger.error("#{__MODULE__} exiting with reason: #{reason |> inspect()}")
        end

        {:stop, reason, nil}
      end

      @impl true
      def terminate(reason, chan) do
        ChannelPool.release_channel(chan)

        case reason do
          :shutdown -> Logger.info("#{__MODULE__} terminating with reason: :shutdown")
          reason -> Logger.error("#{__MODULE__} terminating with reason: #{reason |> inspect()}")
        end

        nil
      end

      defp consume(chan, tag, payload) do
        try do
          Logger.debug("Message received: #{tag}")
          :ok = handle(payload)
          :ok = Basic.ack(chan, tag)
        rescue
          e ->
            {:ok, retries_left} = KV.get(tag, @queue_cache_table)

            Logger.error(
              "Error while processing message:\n#{payload |> inspect()}\nError:#{e |> inspect()}\nRetries left: #{
                retries_left
              }"
            )

            Basic.reject(chan, tag, retries_left > 0)
            KV.put(retries_left - 1, tag, @queue_cache_table)
        end
      end
    end
  end
end
