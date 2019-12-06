defmodule HomeRabbit do
  @moduledoc """
  Documentation for HomeRabbit.
  """
  alias HomeRabbit.ChannelPool
  alias AMQP.Basic

  @type option ::
          {:mandatory, boolean}
          | {:immediate, boolean}
          | {:content_type, String.t()}
          | {:content_encoding, String.t()}
          | {:headers, list({key :: String.t(), value :: term})}
          | {:persistent, boolean}
          | {:correlation_id, String.t()}
          | {:priority, 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9}
          | {:reply_to, String.t()}
          | {:expiration, number}
          | {:message_id, String.t()}
          | {:timestamp, number}
          | {:type, String.t()}
          | {:user_id, String.t()}
          | {:app_id, String.t()}
  @type options :: [option]
  @type message ::
          %{
            exchange: Basic.exchange(),
            routing_key: Basic.routing_key(),
            payload: Basic.payload()
          }
          | %{
              exchange: Basic.exchange(),
              routing_key: Basic.routing_key(),
              payload: Basic.payload(),
              options: options
            }

  def publish(%{exchange: exchange, routing_key: routing_key, payload: payload} = message) do
    {:ok, chan} = ChannelPool.get_channel()
    :ok = Basic.publish(chan, exchange, routing_key, payload, message |> Map.get(:options, []))
    ChannelPool.release_channel(chan)
  end
end
