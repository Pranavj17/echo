defmodule Cto.Application do
  @moduledoc """
  OTP Application for the CTO agent.

  Starts the shared infrastructure (database, Redis) and CTO-specific services.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting CTO Agent...")

    children = [
      # Start shared infrastructure from EchoShared
      EchoShared.Repo,
      {Redix, name: :redix, host: redis_host(), port: redis_port()},
      {Redix.PubSub, name: :redix_pubsub, host: redis_host(), port: redis_port()},

      # CTO-specific services
      Cto.DecisionEngine,
      Cto.MessageHandler
    ]

    opts = [strategy: :one_for_one, name: Cto.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis_host, do: System.get_env("REDIS_HOST", "localhost")
  defp redis_port, do: String.to_integer(System.get_env("REDIS_PORT", "6379"))
end
