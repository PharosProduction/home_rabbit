defmodule HomeRabbit.Message do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      alias AMQP.Basic

      @type t :: %__MODULE__{
              exchange: Basic.exchange(),
              routing_key: Basic.routing_key(),
              payload: Basic.payload(),
              options: HomeRabbit.options()
            }
      @enforce_keys [:exchange, :routing_key, :payload]

      case {Keyword.has_key?(opts, :exchange), Keyword.has_key?(opts, :routing_key)} do
        {true, true} -> defstruct [:option, :payloads | opts]
        {true, false} -> defstruct [:option, :payloads, :routing_key | opts]
        {false, true} -> defstruct [:option, :payloads, :exchange | opts]
        {false, false} -> defstruct [:option | @enforce_keys]
      end
    end
  end
end
