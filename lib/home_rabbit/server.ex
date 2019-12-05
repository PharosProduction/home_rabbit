defmodule HomeRabbit.Server do
  alias AMQP.Connection

  require Logger

  use GenServer

  # Client
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_connection do
    case GenServer.call(__MODULE__, :get) do
      nil -> {:error, :not_connected}
      conn -> {:ok, conn}
    end
  end

  # Server

  @impl true
  def init(_) do
    send(self(), :connect)
    {:ok, nil}
  end

  @impl true
  def handle_call(:get, _, conn) do
    {:reply, conn, conn}
  end

  @impl true
  def handle_info(:connect, _conn) do
    host = Application.get_env(:home_rabbit, :host, "localhost")
    port = Application.get_env(:home_rabbit, :port, 5672)
    username = Application.get_env(:home_rabbit, :username, "guest")
    password = Application.get_env(:home_rabbit, :password, "guest")
    reconnect_interval = Application.get_env(:home_rabbit, :reconnect_interval, 10_000)

    case Connection.open(
           [host: host, port: port, virtual_host: "/", username: username, password: password],
           :undefined
         ) do
      {:ok, conn} ->
        # Get notifications when the connection goes down
        Process.monitor(conn.pid)
        {:noreply, conn}

      {:error, _} ->
        Logger.error(
          "Failed to connect amqp://#{username}:#{password}@#{host}, port: #{port}. Reconnecting later..."
        )

        # Retry later
        Process.send_after(self(), :connect, reconnect_interval)
        {:noreply, nil}
    end
  end

  @impl true
  def handle_info({:DOWN, _, :process, _pid, reason}, _) do
    # Stop GenServer. Will be restarted by Supervisor.
    {:stop, {:connection_lost, reason}, nil}
  end
end
