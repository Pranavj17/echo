defmodule Delegator.AgentSpawner do
  @moduledoc """
  Manages agent lifecycle: spawning, monitoring, and shutdown.

  This module handles the actual spawning of agent processes,
  tracks their health, and provides graceful shutdown capabilities.

  ## Agent Sets

  Predefined agent sets based on task categories:

  - **strategic**: CEO, CTO, Product Manager
  - **technical**: CTO, Senior Architect, Senior Developer
  - **development**: Senior Developer, Test Lead
  - **hr**: CEO, CHRO
  - **operations**: Operations Head, CTO
  - **product**: Product Manager, CEO, UI/UX Engineer
  - **quick_fix**: Senior Developer only

  ## Usage

      # Get agents for a category
      agents = AgentSpawner.get_agents_for_category(:development)
      # [:senior_developer, :test_lead]

      # Spawn all agents for a category
      {:ok, results} = AgentSpawner.spawn_category(:development)

      # Spawn specific agent
      {:ok, port} = AgentSpawner.spawn_agent(:senior_developer)

      # Shutdown agent
      AgentSpawner.shutdown_agent(:senior_developer)

      # Shutdown all agents
      AgentSpawner.shutdown_all_agents()
  """

  require Logger
  alias Delegator.AgentRegistry
  alias Delegator.SessionManager

  @agent_sets %{
    strategic: [:ceo, :cto, :product_manager],
    technical: [:cto, :senior_architect, :senior_developer],
    development: [:senior_developer, :test_lead],
    hr: [:ceo, :chro],
    operations: [:operations_head, :cto],
    product: [:product_manager, :ceo, :uiux_engineer],
    quick_fix: [:senior_developer]
  }

  @agent_models %{
    ceo: "qwen2.5:14b",
    cto: "deepseek-coder:33b",
    chro: "llama3.1:8b",
    operations_head: "mistral:7b",
    product_manager: "llama3.1:8b",
    senior_architect: "deepseek-coder:33b",
    uiux_engineer: "llama3.2-vision:11b",
    senior_developer: "deepseek-coder:6.7b",
    test_lead: "codellama:13b"
  }

  @spawn_timeout Application.compile_env(:delegator, :agent_spawn_timeout, 30_000)

  @type role :: atom()
  @type category ::
          :strategic
          | :technical
          | :development
          | :hr
          | :operations
          | :product
          | :quick_fix

  @doc """
  Get the list of agents for a given task category.

  ## Examples

      AgentSpawner.get_agents_for_category(:development)
      # [:senior_developer, :test_lead]

      AgentSpawner.get_agents_for_category(:strategic)
      # [:ceo, :cto, :product_manager]
  """
  @spec get_agents_for_category(category()) :: [role()]
  def get_agents_for_category(category) do
    Map.get(@agent_sets, category, [:ceo])
  end

  @doc """
  Get all available agent sets.

  Returns a map of category => agent list.

  ## Examples

      AgentSpawner.agent_sets()
      # %{
      #   strategic: [:ceo, :cto, :product_manager],
      #   development: [:senior_developer, :test_lead],
      #   ...
      # }
  """
  @spec agent_sets() :: %{category() => [role()]}
  def agent_sets, do: @agent_sets

  @doc """
  Spawn all agents for a given category.

  Returns `{:ok, results}` where results is a list of
  `{:ok, role}` or `{:error, role, reason}` tuples.

  ## Examples

      {:ok, results} = AgentSpawner.spawn_category(:development)
      # {:ok, [
      #   {:ok, :senior_developer},
      #   {:ok, :test_lead}
      # ]}
  """
  @spec spawn_category(category()) :: {:ok, list()} | {:error, term()}
  def spawn_category(category) do
    agents = get_agents_for_category(category)

    Logger.info("Spawning agents for category",
      category: category,
      agents: agents,
      count: length(agents)
    )

    # Spawn all agents in parallel
    results =
      agents
      |> Enum.uniq()
      |> Enum.map(&spawn_agent/1)

    success_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)
    error_count = length(results) - success_count

    Logger.info("Agent spawn complete",
      category: category,
      success: success_count,
      errors: error_count
    )

    {:ok, results}
  end

  @doc """
  Spawn a specific agent by role.

  The agent is spawned in autonomous mode (--autonomous flag).
  Returns `{:ok, port}` on success, `{:error, reason}` on failure.

  ## Examples

      {:ok, port} = AgentSpawner.spawn_agent(:senior_developer)

      case AgentSpawner.spawn_agent(:ceo) do
        {:ok, port} ->
          IO.puts("CEO spawned successfully")
        {:error, :already_running} ->
          IO.puts("CEO is already running")
        {:error, reason} ->
          IO.puts("Failed to spawn CEO: \#{reason}")
      end
  """
  @spec spawn_agent(role()) :: {:ok, port()} | {:error, term()}
  def spawn_agent(role) do
    # Check if already running
    if AgentRegistry.registered?(role) do
      Logger.debug("Agent already running", role: role)
      {:error, :already_running}
    else
      do_spawn_agent(role)
    end
  end

  defp do_spawn_agent(role) do
    start_time = System.monotonic_time(:millisecond)
    agent_path = get_agent_path(role)

    Logger.info("Spawning agent", role: role, path: agent_path)

    # Check if agent executable exists
    if not File.exists?(agent_path) do
      Logger.error("Agent executable not found",
        role: role,
        path: agent_path
      )

      {:error, {:executable_not_found, agent_path}}
    else
      do_spawn_agent_port(role, agent_path, start_time)
    end
  end

  defp do_spawn_agent_port(role, agent_path, start_time) do
    try do
      # Spawn agent as a port in autonomous mode
      port =
        Port.open(
          {:spawn_executable, agent_path},
          [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            args: ["--autonomous"],
            env: get_agent_env(role)
          ]
        )

      # Register in ETS
      model = Map.get(@agent_models, role, "unknown")

      AgentRegistry.register(role, port, %{
        model: model,
        spawned_at: DateTime.utc_now(),
        spawn_time_ms: System.monotonic_time(:millisecond) - start_time
      })

      # Notify session manager
      SessionManager.agent_spawned(role)

      # Monitor the port for crashes
      spawn_monitor_task(role, port)

      spawn_time = System.monotonic_time(:millisecond) - start_time

      Logger.info("Agent spawned successfully",
        role: role,
        port: inspect(port),
        spawn_time_ms: spawn_time,
        model: model
      )

      {:ok, port}
    rescue
      error ->
        Logger.error("Failed to spawn agent",
          role: role,
          error: inspect(error)
        )

        {:error, {:spawn_failed, error}}
    end
  end

  @doc """
  Shutdown a specific agent gracefully.

  Closes the port and unregisters from registry.

  ## Examples

      AgentSpawner.shutdown_agent(:senior_developer)
      # {:ok, :shutdown}

      AgentSpawner.shutdown_agent(:nonexistent)
      # {:error, :not_running}
  """
  @spec shutdown_agent(role()) :: {:ok, :shutdown} | {:error, :not_running}
  def shutdown_agent(role) do
    case AgentRegistry.lookup(role) do
      {:ok, %{port: port}} ->
        Logger.info("Shutting down agent", role: role)

        try do
          Port.close(port)
        rescue
          error ->
            Logger.warning("Error closing port for agent",
              role: role,
              error: inspect(error)
            )
        end

        AgentRegistry.unregister(role)
        SessionManager.agent_shutdown(role)

        Logger.info("Agent shutdown complete", role: role)
        {:ok, :shutdown}

      :not_found ->
        Logger.debug("Agent not running, cannot shutdown", role: role)
        {:error, :not_running}
    end
  end

  @doc """
  Shutdown all currently running agents.

  This is called when ending a session.

  ## Examples

      AgentSpawner.shutdown_all_agents()
      # {:ok, [
      #   {:ok, :ceo},
      #   {:ok, :senior_developer}
      # ]}
  """
  @spec shutdown_all_agents() :: {:ok, list()}
  def shutdown_all_agents do
    agents = AgentRegistry.all_agents()

    Logger.info("Shutting down all agents", count: length(agents))

    results =
      Enum.map(agents, fn {role, _port, _metadata} ->
        case shutdown_agent(role) do
          {:ok, :shutdown} -> {:ok, role}
          {:error, reason} -> {:error, role, reason}
        end
      end)

    success_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)
    Logger.info("All agents shutdown", total: length(agents), success: success_count)

    {:ok, results}
  end

  @doc """
  Check if an agent is currently running.

  ## Examples

      if AgentSpawner.agent_running?(:ceo) do
        IO.puts("CEO is running")
      end
  """
  @spec agent_running?(role()) :: boolean()
  def agent_running?(role) do
    AgentRegistry.registered?(role)
  end

  @doc """
  Get the LLM model for a given agent role.

  ## Examples

      AgentSpawner.get_model(:ceo)
      # "qwen2.5:14b"
  """
  @spec get_model(role()) :: String.t()
  def get_model(role) do
    Map.get(@agent_models, role, "unknown")
  end

  ## Private Functions

  defp get_agent_path(role) do
    # Determine path relative to delegator app
    base_path = Application.app_dir(:delegator, "../../")
    agent_dir = agent_directory_name(role)
    agent_exec = agent_executable_name(role)

    Path.join([base_path, "apps", agent_dir, agent_exec])
  end

  defp agent_directory_name(:product_manager), do: "product_manager"
  defp agent_directory_name(:operations_head), do: "operations_head"
  defp agent_directory_name(:senior_architect), do: "senior_architect"
  defp agent_directory_name(:senior_developer), do: "senior_developer"
  defp agent_directory_name(:test_lead), do: "test_lead"
  defp agent_directory_name(:uiux_engineer), do: "uiux_engineer"
  defp agent_directory_name(role), do: to_string(role)

  defp agent_executable_name(:product_manager), do: "product_manager"
  defp agent_executable_name(:operations_head), do: "operations_head"
  defp agent_executable_name(:senior_architect), do: "senior_architect"
  defp agent_executable_name(:senior_developer), do: "senior_developer"
  defp agent_executable_name(:test_lead), do: "test_lead"
  defp agent_executable_name(:uiux_engineer), do: "uiux_engineer"
  defp agent_executable_name(role), do: to_string(role)

  defp get_agent_env(role) do
    model = Map.get(@agent_models, role)

    [
      {"#{role |> to_string() |> String.upcase()}_MODEL", model},
      {"AGENT_AUTONOMOUS", "true"}
    ]
  end

  defp spawn_monitor_task(role, port) do
    Task.start(fn ->
      monitor_agent(role, port)
    end)
  end

  defp monitor_agent(role, port) do
    receive do
      {^port, {:exit_status, status}} ->
        Logger.warning("Agent process exited",
          role: role,
          exit_status: status
        )

        AgentRegistry.unregister(role)
        SessionManager.agent_shutdown(role)

      {^port, {:data, data}} ->
        # Log agent output (optional)
        Logger.debug("Agent output", role: role, data: String.trim(data))
        monitor_agent(role, port)

      _ ->
        monitor_agent(role, port)
    end
  end
end
