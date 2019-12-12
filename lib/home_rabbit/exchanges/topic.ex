defmodule HomeRabbit.Exchange.Topic do
  @moduledoc """
  Documentation for HomeRabbit.Exchange.Topic

  ## Examples
  ```elixir
    iex> defmodule TestTopicExchange do
    ...>   use HomeRabbit.Exchange.Topic, exchange: "test_topic_exchange", queues: [[queue: "test_topic_queue", routing_key: "test_topic"]]
    ...>   defmessage TestTopic do
    ...>     def new() do
    ...>       %TestTopic{routing_key: "test_topic", payload: "Hello from TestTopic"}
    ...>     end
    ...>   end
    ...> end
    ...> start_supervised!(TestTopicExchange)
    ...> TestTopicExchange.publish(TestTopicExchange.TestTopic.new())
    :ok

  ```
  """
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use HomeRabbit.Exchange,
        exchange: opts[:exchange],
        exchange_type: :topic,
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

