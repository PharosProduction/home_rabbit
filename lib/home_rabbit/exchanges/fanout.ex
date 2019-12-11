defmodule HomeRabbit.Exchange.Fanout do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use HomeRabbit.Exchange,
        exchange: opts[:exchange],
        type: :fanout,
        qeues: opts[:queues] |> Enum.map(fn [queue: queue] -> queue end)
    end
  end
end
