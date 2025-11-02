defmodule SeniorArchitect.Application do
  @moduledoc """
  OTP Application for the SENIOR_ARCHITECT agent.

  Starts the shared infrastructure (database, Redis) and SENIOR_ARCHITECT-specific services.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting SENIOR_ARCHITECT Agent...")

    children = [
      # Start shared infrastructure from EchoShared
      EchoShared.Repo,
      {Redix, name: :redix, host: redis_host(), port: redis_port()},
      {Redix.PubSub, name: :redix_pubsub, host: redis_host(), port: redis_port()},

      # SENIOR_ARCHITECT-specific services
      Senior_architect.DecisionEngine,
      Senior_architect.MessageHandler
    ]

    opts = [strategy: :one_for_one, name: Senior_architect.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis_host, do: System.get_env("REDIS_HOST", "localhost")
  defp redis_port, do: String.to_integer(System.get_env("REDIS_PORT", "6379"))
end
