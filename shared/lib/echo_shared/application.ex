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

    children = [
      # Ecto repository
      EchoShared.Repo,

      # Redis connection pool
      {Redix, name: :redix, host: redis_host(), port: redis_port()},

      # Workflow engine
      EchoShared.Workflow.Engine
    ]

    opts = [strategy: :one_for_one, name: EchoShared.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis_host do
    System.get_env("REDIS_HOST", "localhost")
  end

  defp redis_port do
    System.get_env("REDIS_PORT", "6379") |> String.to_integer()
  end
end
