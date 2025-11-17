defmodule Delegator.AgentRegistry do
  @moduledoc """
  ETS-based registry for tracking active agents and their PIDs/Ports.

  This module provides a lightweight registry for managing which agents
  are currently spawned and running in a session.

  ## Usage

      # Initialize registry (called by Application)
      AgentRegistry.init()

      # Register a spawned agent
      AgentRegistry.register(:ceo, port, %{model: "qwen2.5:14b"})

      # Lookup an agent
      {:ok, %{port: port, metadata: meta}} = AgentRegistry.lookup(:ceo)

      # List all active agents
      agents = AgentRegistry.all_agents()  # [{:ceo, port, meta}, ...]

      # Unregister when shutting down
      AgentRegistry.unregister(:ceo)
  """

  @table_name :delegator_agent_registry

  @type role :: atom()
  @type port_ref :: port()
  @type metadata :: map()

  @doc """
  Initialize the ETS table for agent registry.
  Called by Delegator.Application on startup.
  """
  @spec init() :: :ok
  def init do
    case :ets.info(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
        :ok

      _ ->
        # Table already exists
        :ok
    end
  end

  @doc """
  Register a spawned agent with its port and metadata.

  ## Parameters

    * `role` - The agent role (e.g., :ceo, :cto, :senior_developer)
    * `port` - The port reference from Port.open/2
    * `metadata` - Optional metadata (e.g., %{model: "...", pid: ...})

  ## Examples

      AgentRegistry.register(:ceo, port, %{
        model: "qwen2.5:14b",
        spawned_at: DateTime.utc_now()
      })
  """
  @spec register(role(), port_ref(), metadata()) :: :ok
  def register(role, port, metadata \\ %{}) do
    entry = {
      role,
      port,
      Map.merge(metadata, %{registered_at: DateTime.utc_now()})
    }

    :ets.insert(@table_name, entry)
    :ok
  end

  @doc """
  Unregister an agent when it shuts down.

  ## Examples

      AgentRegistry.unregister(:ceo)
  """
  @spec unregister(role()) :: :ok
  def unregister(role) do
    :ets.delete(@table_name, role)
    :ok
  end

  @doc """
  Look up a registered agent by role.

  Returns `{:ok, %{port: port, metadata: map}}` if found,
  `:not_found` otherwise.

  ## Examples

      case AgentRegistry.lookup(:ceo) do
        {:ok, %{port: port, metadata: meta}} ->
          # Agent is running
        :not_found ->
          # Agent not spawned
      end
  """
  @spec lookup(role()) :: {:ok, %{port: port_ref(), metadata: metadata()}} | :not_found
  def lookup(role) do
    case :ets.lookup(@table_name, role) do
      [{^role, port, metadata}] ->
        {:ok, %{port: port, metadata: metadata}}

      [] ->
        :not_found
    end
  end

  @doc """
  Check if an agent is currently registered.

  ## Examples

      if AgentRegistry.registered?(:ceo) do
        # CEO is running
      end
  """
  @spec registered?(role()) :: boolean()
  def registered?(role) do
    case lookup(role) do
      {:ok, _} -> true
      :not_found -> false
    end
  end

  @doc """
  Get all registered agents.

  Returns a list of tuples: `[{role, port, metadata}, ...]`

  ## Examples

      agents = AgentRegistry.all_agents()
      # [{:ceo, #Port<0.5>, %{...}}, {:cto, #Port<0.6>, %{...}}]

      roles = Enum.map(agents, fn {role, _port, _meta} -> role end)
      # [:ceo, :cto]
  """
  @spec all_agents() :: [{role(), port_ref(), metadata()}]
  def all_agents do
    :ets.tab2list(@table_name)
  end

  @doc """
  Get the count of currently registered agents.

  ## Examples

      count = AgentRegistry.agent_count()
      # 3
  """
  @spec agent_count() :: non_neg_integer()
  def agent_count do
    :ets.info(@table_name, :size)
  end

  @doc """
  Clear all registered agents (use with caution).

  This does NOT shut down the actual agent processes,
  it only clears the registry. Use for cleanup after
  emergency shutdown.

  ## Examples

      AgentRegistry.clear_all()
  """
  @spec clear_all() :: :ok
  def clear_all do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @doc """
  Get metadata for a specific agent.

  ## Examples

      case AgentRegistry.get_metadata(:ceo) do
        {:ok, %{model: model, spawned_at: time}} ->
          # Use metadata
        :not_found ->
          # Agent not running
      end
  """
  @spec get_metadata(role()) :: {:ok, metadata()} | :not_found
  def get_metadata(role) do
    case lookup(role) do
      {:ok, %{metadata: metadata}} -> {:ok, metadata}
      :not_found -> :not_found
    end
  end

  @doc """
  Update metadata for an agent (e.g., add health check info).

  ## Examples

      AgentRegistry.update_metadata(:ceo, %{last_heartbeat: DateTime.utc_now()})
  """
  @spec update_metadata(role(), map()) :: :ok | :not_found
  def update_metadata(role, updates) do
    case lookup(role) do
      {:ok, %{port: port, metadata: existing_meta}} ->
        new_meta = Map.merge(existing_meta, updates)
        register(role, port, new_meta)
        :ok

      :not_found ->
        :not_found
    end
  end
end
