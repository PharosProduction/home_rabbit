defmodule HomeRabbit.ChannelPool do
  alias HomeRabbit.ConnectionManager
  alias AMQP.{Channel, Basic}

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
    send(self(), :connect)
    {:ok, []}
  end

  @impl true
  def handle_call(:get_channel, _from, pool) do
    if pool |> Enum.any?() do
      [chan | rest] = pool
      {:reply, {:ok, chan}, rest}
    else
      with {:ok, conn} <- ConnectionManager.get_connection(),
           {:ok, chan} <- Channel.open(conn) do
        # TODO: do I really need this?
        :ok =
          Basic.qos(chan, prefetch_count: Application.get_env(:home_rabbit, :prefetch_count, 10))

        {:reply, {:ok, chan}, pool}
      else
        _ -> {:reply, {:error, :not_connected}, pool}
      end
    end
  end

  @impl true
  def handle_cast({:release_channel, nil}, pool) do
    {:noreply, pool}
  end

  @impl true
  def handle_cast({:release_channel, channel}, pool) do
    limit = Application.get_env(:home_rabbit, :max_cannels, 1)
    count = Enum.count(pool)
    Logger.debug("Channel limit: #{limit}")

    case limit do
      limit when limit == :infinite or limit > count ->
        Logger.debug("Channel count: #{count + 1}")
        {:noreply, [channel | pool]}

      limit when limit <= count ->
        close_channel(channel)
        Logger.debug("Channel count: #{count}")
        {:noreply, pool}

      wrong_argument ->
        Logger.warn("Wrong configuration for :home_rabbit :max_channels: #{wrong_argument}")
        Logger.debug("Channel count: #{count}")
        {:noreply, [pool]}
    end
  end

  @impl true
  def handle_info(:connect, _conn) do
    reconnect_interval = Application.get_env(:home_rabbit, :reconnect_interval, 10_000)

    with {:ok, conn} <- ConnectionManager.get_connection(),
         {:ok, chan} <- Channel.open(conn) do
      # Get notifications when the connection goes down
      Process.monitor(conn.pid)
      # TODO: do I really need this?
      :ok =
        Basic.qos(chan, prefetch_count: Application.get_env(:home_rabbit, :prefetch_count, 10))

      {:noreply, [chan]}
    else
      {:error, _} ->
        # Retry later
        Process.send_after(self(), :connect, reconnect_interval)
        {:noreply, []}
    end
  end

  @impl true
  def handle_info({:DOWN, _, :process, _pid, reason}, pool) do
    # Stop GenServer. Will be restarted by Supervisor.
    pool |> Enum.each(&close_channel/1)
    {:stop, {:connection_lost, reason}, nil}
  end

  @impl true
  def handle_info({:EXIT, _from, reason}, pool) do
    pool |> Enum.each(&close_channel/1)

    case reason do
      :shutdown -> Logger.info("#{__MODULE__} exiting with reason: :shutdown")
      reason -> Logger.error("#{__MODULE__} exiting with reason: #{reason |> inspect()}")
    end

    {:stop, reason, []}
  end

  @impl true
  def terminate(reason, pool) do
    pool |> Enum.each(&close_channel/1)

    case reason do
      :shutdown -> Logger.info("#{__MODULE__} terminating with reason: :shutdown")
      reason -> Logger.error("#{__MODULE__} terminating with reason: #{reason |> inspect()}")
    end

    []
  end

  defp close_channel(channel) when not is_nil(channel), do: Channel.close(channel)

  defp close_channel(nil), do: :ok
end
