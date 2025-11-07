defmodule ProductManager.Application do
  @moduledoc """
  OTP Application for the PRODUCT_MANAGER agent.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting PRODUCT_MANAGER Agent...")

    children = [
      %{
        id: Redix.PubSub,
        start: {Redix.PubSub, :start_link, [[name: :redix_pubsub, host: redis_host(), port: redis_port()]]}
      },

      # Heartbeat worker
      {EchoShared.HeartbeatWorker, role: :product_manager, metadata: %{version: "1.0.0"}},

      ProductManager.DecisionEngine,
      ProductManager.MessageHandler
    ]

    opts = [strategy: :one_for_one, name: ProductManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis_host, do: System.get_env("REDIS_HOST", "localhost")
  defp redis_port, do: String.to_integer(System.get_env("REDIS_PORT", "6383"))
end
