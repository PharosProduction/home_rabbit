defmodule HomeRabbit.Observer do
  @moduledoc """
  Documentation for HomeRabbit.Observer
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
      @queue_cache_table :"#{@queue}"
      @max_retries opts |> Keyword.get(:max_retries, 0)

      def start_link(_opts) do
        GenServer.start_link(__MODULE__, nil, name: __MODULE__)
      end

      @impl true
      def init(_) do
        {:ok, chan} = ChannelPool.get_channel()
        # Register the GenServer process as a consumer
        {:ok, _consumer_tag} = Basic.consume(chan, @queue)

        KV.add_table(@queue_cache_table)

        Logger.debug("Observer #{__MODULE__} initialized")
        {:ok, chan}
      end

      # Confirmation sent by the broker after registering this process as a consumer
      @impl true
      def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, chan) do
        {:noreply, chan}
      end

      @impl true
      def handle_info({_ref, :ok}, %AMQP.Channel{} = chan) do
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
      def terminate(reason, chan) do
        ChannelPool.release_channel(chan)
        Logger.error("Terminating with #{reason |> inspect()}")
      end

      defp consume(chan, tag, payload) do
        try do
          Logger.debug("Message received: #{tag}")
          :ok = handle(payload)
          :ok = Basic.ack(chan, tag)
        rescue
          e ->
            {:ok, retries_left} = KV.get(tag, @queue)

            Logger.error(
              "Error while processing message:\n#{payload |> inspect()}\nError:#{e |> inspect()}\nRetries left: #{
                retries_left
              }"
            )

            Basic.reject(chan, tag, retries_left > 0)
            KV.put(retries_left - 1, tag, @queue_cache_table)
        catch
          :exit, reason ->
            Logger.error(
              "EXIT signal with #{reason |> inspect()} - fail to process a message:\n#{payload}\nQueue:#{
                @queue
              }"
            )

            status = Queue.status(chan, @queue)
            Logger.error("Queue status: #{inspect(status)}")
        end
      end
    end
  end
end
