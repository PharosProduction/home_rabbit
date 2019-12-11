defmodule HomeRabbit.Exchange.Direct do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use HomeRabbit.Exchange,
        exchange: opts[:exchange],
        type: :direct,
        qeues:
          opts[:queues]
          |> Enum.map(fn [queue: queue, routing_key: routing_key] -> {queue, routing_key} end)
    end
  end
end

