defmodule HomeRabbit.Exchange do
  alias AMQP.Basic

  @callback get_queue(
              queue ::
                Basic.queue()
                | {queue :: Basic.queue(), routing_key :: Basic.routing_key()}
                | {queue :: Basic.queue(), arguments :: [{key :: String.t(), value :: term}, ...],
                   x_match :: {String.t(), String.t()}}
            ) :: Basic.queue()

  @callback bind_queue(
              channel :: Basic.channel(),
              queue ::
                Basic.queue()
                | {queue :: Basic.queue(), routing_key :: Basic.routing_key()}
                | {queue :: Basic.queue(), arguments :: [{key :: String.t(), value :: term}, ...],
                   x_match :: {String.t(), String.t()}},
              exchange :: Basic.exchange()
            ) :: :ok | {:error, reason :: term}

  defmacro defmessage(message_name, do: body) do
    quote do
      exchange = Module.get_attribute(__MODULE__, :exchange)
      message_alias = Module.concat(__MODULE__, unquote(message_name))

      defmodule message_alias do
        use HomeRabbit.Message, exchange: exchange
        alias __MODULE__

        unquote(body)
      end
    end
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      alias HomeRabbit.ChannelPool
      alias AMQP.{Basic, Queue, Exchange}

      import HomeRabbit.Exchange

      require Logger

      use GenServer

      @behaviour HomeRabbit.Exchange

      @exchange opts[:exchange]
      @exchange_type opts[:exchange_type]
      @queues opts[:queues]
      @errors_queue Keyword.get(opts, :errors_queue, nil)
      @errors_exchange Keyword.get(opts, :errors_exchange, nil)
      @exchange_table __MODULE__

      @spec publish(message :: HomeRabbit.message()) :: :ok | {:error, reason :: term}
      def publish(routing_key: routing_key, payload: payload, options: options)
          when payload |> is_binary() do
            GenServer.call(__MODULE__, {:publish, routing_key: routing_key, payload: payload, options: options})
      end

      def publish(%{routing_key: routing_key, payload: payload} = message)
          when payload |> is_binary() do
        options = message |> Map.get(:options, [])
            GenServer.call(__MODULE__, {:publish, routing_key: routing_key, payload: payload, options: options})
      end

      def publish(message), do: {:error, {:wrong_payload_format, message}}

      defp process_requests([[routing_key: routing_key, payload: payload, options: options] | rest], chan) do
        :ok = Basic.publish(chan, @exchange, routing_key, payload, options)

        Logger.debug(
          "Message published to exchange #{@exchange} with routing key: #{routing_key} and options: #{
            options |> inspect()
          }"
        )

        KV.put(rest, :requests, @exchange_table)
        process_requests(rest)
      end

      defp process_requests([], chan), do: ChannelPool.release_channel(chan)

      defp process_requests(from) do
        with {:ok, true} <- KV.get(:setup_finished, @exchange_table),
             {:ok, chan} <- ChannelPool.get_channel(),
             {:ok, requests} <- KV.get(:requests, @exchange_table) do
          requests |> process_requests(chan)
        else
          _ ->
            pid = self()
            reconnect_interval = Application.get_env(:home_rabbit, :reconnect_interval, 10_000)

            spawn_link(fn ->
              Process.sleep(reconnect_interval)
              result = GenServer.call(pid, :process_requests)
              GenServer.reply(from, result)
            end)
        end
      end

      def start_link(_opts) do
        GenServer.start_link(__MODULE__, nil, name: __MODULE__)
      end

      # Server
      @impl true
      def init(_opts) do
        KV.add_table(@exchange_table)
        KV.put(false, :setup_finished, @exchange_table)
        KV.put([], :requests, @exchange_table)

        send(self(), :connect)
        {:ok, nil}
      end

      @impl true
      def handle_call(:process_requests, from, state) do
        process_requests(from)
        {:noreply, state}
      end

      @impl true
      def handle_call({:publish, request}, from, state) do
        {:ok, requests} = KV.get(:requests, @exchange_table)
        KV.put([request | requests], :requests, @exchange_table)
        process_requests(from)
        {:reply, :ok, state}
      end

      @impl true
      def handle_info(:connect, _conn) do
        reconnect_interval = Application.get_env(:home_rabbit, :reconnect_interval, 10_000)

        with {:ok, chan} <- ChannelPool.get_channel() do
          {:ok, chan} = ChannelPool.get_channel()

          setup_exchange(chan, @queues)

          ChannelPool.release_channel(chan)

          KV.put(true, :setup_finished, @exchange_table)

          {:noreply, nil}
        else
          {:error, _} ->
            # Retry later
            Process.send_after(self(), :connect, reconnect_interval)
            {:noreply, nil}
        end
      end

      # Setup

      defp setup_exchange(chan, queues) do
        with :ok <- Exchange.declare(chan, @exchange, @exchange_type, durable: true) do
          Logger.debug(
            "Exchange was declared:\nExchange: #{@exchange}\nType: #{@exchange_type |> inspect()}"
          )

          queues |> Enum.each(&setup_queue(chan, &1, fn -> bind_queue(chan, &1, @exchange) end))
        else
          {:error, reason} ->
            Logger.error("Failed exchange setup:\nExchange: #{@exchange}\nReason: #{reason}")
        end
      end

      defp setup_queue(chan, queue, bind_fn) do
        with queue <- queue |> get_queue(),
             {:ok, _res} <- queue |> declare_queue(chan),
             :ok <- bind_fn.() do
          Logger.debug(
            "Queue was declared and bound to exchange:\nQueue: #{queue}\nExchange: #{@exchange}"
          )
        else
          {:error, reason} ->
            Logger.error("Failed queue setup:\nQueue: #{queue}\nReason: #{reason}")
        end
      end

      defp declare_queue(queue, chan) do
        if queue == @errors_queue or is_nil(@errors_queue) do
          Queue.declare(chan, queue, durable: true)
        else
          Queue.declare(chan, queue,
            durable: true,
            arguments: [
              {"x-dead-letter-exchange", :longstr, @errors_exchange},
              {"x-dead-letter-routing-key", :longstr, @errors_queue}
            ]
          )
        end
      end
    end
  end
end
