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

      @enforce_keys (case {Keyword.has_key?(opts, :exchange),
                           Keyword.has_key?(opts, :routing_key)} do
                       {true, true} -> [:payload]
                       {true, false} -> [:payload, :routing_key]
                       {false, true} -> [:payload, :exchange]
                       {false, false} -> [:payload, :exchange, :routing_key]
                     end)

      case {Keyword.has_key?(opts, :exchange), Keyword.has_key?(opts, :routing_key)} do
        {true, true} -> [:payload, options: []] ++ opts
        {true, false} -> [:payload, :routing_key, options: []] ++ opts
        {false, true} -> [:payload, :exchange, options: []] ++ opts
        {false, false} -> @enforce_keys ++ [options: []]
      end
      |> defstruct
    end
  end
end
