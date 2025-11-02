defmodule UiuxEngineer.Application do
  @moduledoc """
  OTP Application for the UIUX_ENGINEER agent.

  Starts the shared infrastructure (database, Redis) and UIUX_ENGINEER-specific services.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting UIUX_ENGINEER Agent...")

    children = [
      # Start shared infrastructure from EchoShared
      EchoShared.Repo,
      {Redix, name: :redix, host: redis_host(), port: redis_port()},
      {Redix.PubSub, name: :redix_pubsub, host: redis_host(), port: redis_port()},

      # UIUX_ENGINEER-specific services
      Uiux_engineer.DecisionEngine,
      Uiux_engineer.MessageHandler
    ]

    opts = [strategy: :one_for_one, name: Uiux_engineer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis_host, do: System.get_env("REDIS_HOST", "localhost")
  defp redis_port, do: String.to_integer(System.get_env("REDIS_PORT", "6379"))
end
