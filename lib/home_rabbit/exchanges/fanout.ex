defmodule HomeRabbit.Exchange.Fanout do
  @moduledoc """
  Documentation for HomeRabbit.Exchange.Fanout

  ## Examples
  ```elixir
    iex> defmodule TestFanoutExchange do
    ...>   use HomeRabbit.Exchange.Fanout, exchange: "test_fanout_exchange", queues: [[queue: "test_fanout_queue"]]
    ...>   defmessage TestFanout do
    ...>     def new() do
    ...>       %TestFanout{routing_key: "test_fanout", payload: "Hello from TestFanout"}
    ...>     end
    ...>   end
    ...> end
    ...> start_supervised!(TestFanoutExchange)
    ...> TestFanoutExchange.publish(TestFanoutExchange.TestFanout.new())
    :ok

  ```
  """

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      alias AMQP.Queue
      use HomeRabbit.Exchange,
        exchange: opts[:exchange],
        exchange_type: :fanout,
        queues: opts[:queues] |> Enum.map(fn [queue: queue] -> queue end)

      @impl true
      def get_queue(queue), do: queue

      @impl true
      def bind_queue(channel, queue, exchange) do
        AMQP.Queue.bind(channel, queue, exchange)
      end
    end
  end
end
