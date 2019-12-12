defmodule HomeRabbit.Exchange.Direct do
  @moduledoc """
  Documentation for HomeRabbit.Exchange.Direct

  ## Examples
  ```elixir
    iex> defmodule TestDirectExchange do
    ...>   use HomeRabbit.Exchange.Direct, exchange: "test_direct_exchange", queues: [[queue: "test_direct_queue", routing_key: "test_direct"]]
    ...>   defmessage TestDirect do
    ...>     def new() do
    ...>       %TestDirect{routing_key: "test_direct", payload: "Hello from TestDirect"}
    ...>     end
    ...>   end
    ...> end
    ...> start_supervised!(TestDirectExchange)
    ...> TestDirectExchange.publish(TestDirectExchange.TestDirect.new())
    :ok

  ```
  """
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use HomeRabbit.Exchange,
        exchange: opts[:exchange],
        exchange_type: :direct,
        queues:
          opts[:queues]
          |> Enum.map(fn [queue: queue, routing_key: routing_key] -> {queue, routing_key} end)

      @impl true
      def get_queue({queue, _}), do: queue

      @impl true
      def bind_queue(channel, {queue, routing_key}, exchange) do
        AMQP.Queue.bind(channel, queue, exchange, routing_key: routing_key)
      end
    end
  end
end
