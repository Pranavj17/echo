defmodule ProductManager.Application do
  @moduledoc """
  OTP Application for the PRODUCT_MANAGER agent.

  Starts the shared infrastructure (database, Redis) and PRODUCT_MANAGER-specific services.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting PRODUCT_MANAGER Agent...")

    children = [
      # Start shared infrastructure from EchoShared
      EchoShared.Repo,
      {Redix, name: :redix, host: redis_host(), port: redis_port()},
      {Redix.PubSub, name: :redix_pubsub, host: redis_host(), port: redis_port()},

      # PRODUCT_MANAGER-specific services
      Product_manager.DecisionEngine,
      Product_manager.MessageHandler
    ]

    opts = [strategy: :one_for_one, name: Product_manager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis_host, do: System.get_env("REDIS_HOST", "localhost")
  defp redis_port, do: String.to_integer(System.get_env("REDIS_PORT", "6379"))
end
