defmodule EchoShared.HeartbeatWorker do
  @moduledoc """
  Sends periodic heartbeats to the AgentHealthMonitor.

  Each agent should start this worker to report its health status.
  Heartbeats are sent every 5 seconds.
  """

  use GenServer
  require Logger

  @heartbeat_interval 5_000  # 5 seconds

  ## Client API

  @doc """
  Starts the heartbeat worker for a specific agent role.

  ## Options
  - `:role` - The agent role (required)
  - `:metadata` - Additional metadata to include in heartbeats (optional)
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    role = Keyword.fetch!(opts, :role)
    metadata = Keyword.get(opts, :metadata, %{})

    Logger.info("HeartbeatWorker starting for #{role}")

    # Send first heartbeat immediately
    send_heartbeat(role, metadata)

    # Schedule periodic heartbeats
    schedule_heartbeat()

    {:ok, %{role: role, metadata: metadata}}
  end

  @impl true
  def handle_info(:send_heartbeat, state) do
    send_heartbeat(state.role, state.metadata)
    schedule_heartbeat()
    {:noreply, state}
  end

  ## Private Functions

  defp schedule_heartbeat do
    Process.send_after(self(), :send_heartbeat, @heartbeat_interval)
  end

  defp send_heartbeat(role, metadata) do
    enhanced_metadata = Map.merge(metadata, %{
      timestamp: DateTime.utc_now(),
      node: Node.self()
    })

    EchoShared.AgentHealthMonitor.record_heartbeat(role, enhanced_metadata)
  end
end
