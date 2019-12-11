defmodule HomeRabbit.Exchange.Headers do
  alias AMQP.Basic
  @type x_match :: :any | :all
  @type x_match_arguments :: {key :: String.t(), value :: term}
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
        type: :headers,
        qeues:
          opts[:queues]
          |> Enum.map(fn [queue: queue, x_match: x_match, arguments: arguments] ->
            HomeRabbit.Exchange.Headers.queue(queue, x_match, arguments)
          end)
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

