defmodule HomeRabbit.Exchange do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      alias HomeRabbit.{ChannelPool, Exchange}
      alias AMQP.{Basic, Queue}

      require Logger

      use GenServer

      @exchange opts[:exchange]
      @type opts[:type]
      @queues opts[:queues]

      defmacro defmessage(message_name, do: body) do
        quote bind_quoted: [message_name: message_name] do
          defmodule "#{__MODULE__}.#{message_name}" |> String.to_atom() do
            use HomeRabbit.Message, exchange: @exchange
            unquote(body)
          end
        end

        # Server
        @impl true
        def init(_opts) do
          {:ok, chan} = ChannelPool.get_channel()

          setup_exchange(chan, @queues)

          ChannelPool.release_channel(chan)
          {:ok, nil}
        end

        def start_link(_opts) do
          GenServer.start_link(__MODULE__, nil, name: __MODULE__)
        end

        # Setup

        defp setup_exchange(chan, queues) do
          with :ok <- Exchange.declare(chan, @exchange, @type, durable: true) do
            Logger.debug(
              "Exchange was declared:\nExchange: #{@exchange}\nType: #{@type |> inspect()}"
            )

            case @type do
              :fanout ->
                queues
                |> Enum.each(
                  &setup_queue(chan, exchange, &1, fn -> Queue.bind(chan, &1, exchange) end)
                )

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
    end
  end
end
