defmodule HomeRabbit.Exchange.Headers do
  @moduledoc """
  Documentation for HomeRabbit.Exchange.Headers

  ## Examples
  ```elixir
    iex> defmodule TestHeadersExchange do
    ...>   use HomeRabbit.Exchange.Headers, exchange: "test_headers_exchange", queues: [[queue: "test_headers_queue", x_match: :any, arguments: [{"x_test", true}]]]
    ...>   defmessage TestHeaders do
    ...>     def new() do
    ...>       %TestHeaders{routing_key: "test_headers", payload: "Hello from TestHeaders", options: [{"x_test", true}]}
    ...>     end
    ...>   end
    ...> end
    ...> start_supervised!(TestHeadersExchange)
    ...> TestHeadersExchange.publish(TestHeadersExchange.TestHeaders.new())
    :ok

  ```
  """
  alias AMQP.Basic
  @type x_match :: :any | :all
  @type x_match_arguments :: [{key :: String.t(), value :: term}, ...]
  @typedoc """
    {"x-match", "any"} | {"x-match", "all"}
  """
  @type x_match_configuration :: {String.t(), String.t()}
  @type headers_queue_configuration ::
          {queue :: Basic.queue(), arguments :: x_match_arguments,
           x_match :: x_match_configuration}

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do

      use HomeRabbit.Exchange,
        exchange: opts[:exchange],
        exchange_type: :headers,
        queues:
          opts[:queues]
          |> Enum.map(fn [queue: queue, x_match: x_match, arguments: arguments] ->
            HomeRabbit.Exchange.Headers.queue(queue, x_match, arguments)
          end)

      @impl true
      def get_queue({queue, _, _}), do: queue

      @impl true
      def bind_queue(channel, {queue, arguments, x_match}, exchange) do
        AMQP.Queue.bind(channel, queue, exchange, arguments: arguments ++ [x_match])
      end
    end
  end

  @spec queue(queue :: Basic.queue(), match :: :any, arguments :: x_match_arguments) ::
          headers_queue_configuration
  def queue(queue, :any, arguments) do
    {queue, arguments, {"x-match", "any"}}
  end

  @spec queue(queue :: Basic.queue(), match :: :all, arguments :: x_match_arguments) ::
          headers_queue_configuration
  def queue(queue, :all, arguments) do
    {queue, arguments, {"x-match", "all"}}
  end
end
