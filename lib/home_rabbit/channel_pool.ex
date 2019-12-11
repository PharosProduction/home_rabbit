defmodule HomeRabbit.ChannelPool do
  alias HomeRabbit.ConnectionManager
  alias AMQP.{Channel, Basic, Queue, Exchange}

  require Logger

  use GenServer

  # Client
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def release_channel(channel) do
    GenServer.cast(__MODULE__, {:release_channel, channel})
  end

  def get_channel() do
    GenServer.call(__MODULE__, :get_channel)
  end

  # Server
  @impl true
  def init(_opts) do
    {:ok, con} = ConnectionManager.get_connection()
    {:ok, chan} = Channel.open(con)

    # TODO: do I really need this?
    :ok = Basic.qos(chan, prefetch_count: Application.get_env(:home_rabbit, :prefetch_count, 10))

    {:ok, [chan]}
  end

  @impl true
  def handle_call(:get_channel, _from, pool) do
    if pool |> Enum.any?() do
      [chan | rest] = pool
      {:reply, {:ok, chan}, rest}
    else
      {:ok, con} = ConnectionManager.get_connection()
      {:ok, chan} = Channel.open(con)

      # TODO: do I really need this?
      :ok =
        Basic.qos(chan, prefetch_count: Application.get_env(:home_rabbit, :prefetch_count, 10))

      {:reply, {:ok, chan}, pool}
    end
  end

  @impl true
  def handle_cast({:release_channel, channel}, pool) do
    limit = Application.get_env(:home_rabbit, :max_cannels, :infinite)
    count = Enum.count(pool)
    Logger.debug("Channel limit: #{limit}")

    case limit do
      limit when limit == :infinite or limit > count ->
        Logger.debug("Channel count: #{count + 1}")
        {:noreply, [channel | pool]}

      limit when limit <= count ->
        Channel.close(channel)
        Logger.debug("Channel count: #{count}")
        {:noreply, pool}

      wrong_argument ->
        Logger.warn("Wrong configuration for :home_rabbit :max_channels: #{wrong_argument}")
        Logger.debug("Channel count: #{count + 1}")
        {:noreply, [channel | pool]}
    end
  end

  defp read_settings({application_name, file}) do
    priv_dir = :code.priv_dir(application_name)
    Path.expand(file, priv_dir) |> Code.eval_file()
  end
end
