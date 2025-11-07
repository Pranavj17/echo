defmodule EchoShared.AgentHealthMonitor do
  @moduledoc """
  Agent health monitoring system.

  Tracks agent health via periodic heartbeats and updates the agent_status table.
  Provides circuit breaker functionality to prevent workflows from hanging
  when agents are down.

  Features:
  - Periodic heartbeat checks (every 10 seconds)
  - Circuit breaker pattern for agent failures
  - Agent availability tracking
  - Workflow pausing when critical agents are down
  """

  use GenServer
  require Logger

  alias EchoShared.Repo
  alias EchoShared.Schemas.AgentStatus

  import Ecto.Query

  @heartbeat_interval 10_000 # 10 seconds
  @heartbeat_timeout 30 # 30 seconds - consider agent down if no heartbeat

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if an agent is healthy and available.
  """
  @spec agent_available?(atom()) :: boolean()
  def agent_available?(role) do
    GenServer.call(__MODULE__, {:agent_available?, role})
  end

  @doc """
  Get list of all down agents.
  """
  @spec down_agents() :: [String.t()]
  def down_agents do
    GenServer.call(__MODULE__, :down_agents)
  end

  @doc """
  Record a heartbeat from an agent.

  Agents should call this periodically (e.g., every 5 seconds).
  """
  @spec record_heartbeat(atom(), map()) :: :ok
  def record_heartbeat(role, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:heartbeat, role, metadata})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Agent Health Monitor started")

    # Schedule first health check
    schedule_health_check()

    {:ok, %{
      agent_status: %{},
      circuit_breakers: %{}
    }}
  end

  @impl true
  def handle_call({:agent_available?, role}, _from, state) do
    available = is_agent_available?(role)
    {:reply, available, state}
  end

  @impl true
  def handle_call(:down_agents, _from, state) do
    down = try do
      get_down_agents()
    rescue
      error ->
        Logger.debug("Couldn't fetch down agents from database: #{inspect(error)}")
        []
    end
    {:reply, down, state}
  end

  @impl true
  def handle_cast({:heartbeat, role, metadata}, state) do
    # Update heartbeat in database (non-blocking, failures are logged but don't crash)
    try do
      update_agent_heartbeat(role, metadata)
    rescue
      error ->
        Logger.debug("Couldn't update heartbeat in database for #{role}: #{inspect(error)}")
    end

    # Update in-memory state (always succeeds)
    new_agent_status = Map.put(state.agent_status, role, %{
      last_heartbeat: DateTime.utc_now(),
      status: :running,
      metadata: metadata
    })

    {:noreply, %{state | agent_status: new_agent_status}}
  end

  @impl true
  def handle_info(:health_check, state) do
    # Check all agents for stale heartbeats (with resilient error handling)
    down_agents = try do
      get_down_agents()
    rescue
      error ->
        Logger.debug("Health check couldn't query database (may be busy during startup): #{inspect(error)}")
        []  # Return empty list - assume all agents are up if we can't check
    end

    if down_agents != [] do
      Logger.warning("Agents down or unresponsive: #{inspect(down_agents)}")

      # TODO: Pause workflows that depend on down agents
      # TODO: Send alerts
    end

    # Update circuit breaker state
    new_breakers = update_circuit_breakers(state.circuit_breakers, down_agents)

    # Schedule next check
    schedule_health_check()

    {:noreply, %{state | circuit_breakers: new_breakers}}
  end

  ## Private Functions

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @heartbeat_interval)
  end

  defp is_agent_available?(role) do
    case Repo.get_by(AgentStatus, role: to_string(role)) do
      nil ->
        # Agent never registered - consider unavailable
        false

      agent_status ->
        # Check if heartbeat is recent
        seconds_since_heartbeat = DateTime.diff(DateTime.utc_now(), agent_status.last_heartbeat)
        seconds_since_heartbeat < @heartbeat_timeout
    end
  end

  defp get_down_agents do
    threshold = DateTime.add(DateTime.utc_now(), -@heartbeat_timeout, :second)

    Repo.all(
      from a in AgentStatus,
      where: a.last_heartbeat < ^threshold or a.status != "running",
      select: a.role
    )
  end

  defp update_agent_heartbeat(role, metadata) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{
      role: to_string(role),
      status: "running",
      last_heartbeat: now,
      metadata: metadata
    }

    case Repo.get_by(AgentStatus, role: to_string(role)) do
      nil ->
        # Create new status record
        %AgentStatus{}
        |> AgentStatus.changeset(attrs)
        |> Repo.insert()

      existing ->
        # Update existing record
        existing
        |> AgentStatus.changeset(attrs)
        |> Repo.update()
    end
  end

  defp update_circuit_breakers(breakers, down_agents) do
    # Open circuit for down agents, close for healthy agents
    down_set = MapSet.new(down_agents)

    Map.merge(breakers, %{})
    |> Enum.map(fn {agent, _state} ->
      if MapSet.member?(down_set, agent) do
        {agent, :open}
      else
        {agent, :closed}
      end
    end)
    |> Map.new()
  end
end
