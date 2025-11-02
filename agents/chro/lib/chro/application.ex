defmodule Chro.Application do
  @moduledoc """
  OTP Application for the CHRO agent.

  Starts the shared infrastructure (database, Redis) and CHRO-specific services.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting CHRO Agent...")

    children = [
      # Start shared infrastructure from EchoShared
      EchoShared.Repo,
      {Redix, name: :redix, host: redis_host(), port: redis_port()},
      {Redix.PubSub, name: :redix_pubsub, host: redis_host(), port: redis_port()},

      # CHRO-specific services
      Chro.DecisionEngine,
      Chro.MessageHandler
    ]

    opts = [strategy: :one_for_one, name: Chro.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis_host, do: System.get_env("REDIS_HOST", "localhost")
  defp redis_port, do: String.to_integer(System.get_env("REDIS_PORT", "6379"))
end
