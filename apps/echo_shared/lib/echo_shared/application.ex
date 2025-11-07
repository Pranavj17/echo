defmodule EchoShared.Application do
  @moduledoc """
  Application supervisor for ECHO Shared library.

  Starts and supervises:
  - Ecto repository (PostgreSQL connection pool)
  - Redis connection pool
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting ECHO Shared library...")

    # Base children that all applications need
    base_children = [
      # Ecto repository
      EchoShared.Repo,

      # Redis connection pool (for commands)
      {Redix, name: :redix, host: redis_host(), port: redis_port()},

      # Note: Redix.PubSub is started by each agent's Application module
      # (see agents/*/lib/*/application.ex) not here to avoid conflicts

      # Agent health monitor
      EchoShared.AgentHealthMonitor
    ]

    # Add Workflow Engine only if enabled (for workflow orchestrator, not agents)
    children = if workflow_engine_enabled?() do
      base_children ++ [EchoShared.Workflow.Engine]
    else
      base_children
    end

    opts = [strategy: :one_for_one, name: EchoShared.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp workflow_engine_enabled? do
    System.get_env("WORKFLOW_ENGINE_ENABLED", "false") == "true"
  end

  defp redis_host do
    System.get_env("REDIS_HOST", "localhost")
  end

  defp redis_port do
    System.get_env("REDIS_PORT", "6383") |> String.to_integer()  # Changed default to match Docker
  end
end
