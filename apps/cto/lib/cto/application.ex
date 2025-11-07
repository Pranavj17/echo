defmodule Cto.Application do
  @moduledoc """
  OTP Application for the CTO agent.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting CTO Agent...")

    children = [
      %{
        id: Redix.PubSub,
        start: {Redix.PubSub, :start_link, [[name: :redix_pubsub, host: redis_host(), port: redis_port()]]}
      },

      # Heartbeat worker
      {EchoShared.HeartbeatWorker, role: :cto, metadata: %{version: "1.0.0"}},

      Cto.DecisionEngine,
      Cto.MessageHandler
    ]

    opts = [strategy: :one_for_one, name: Cto.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis_host, do: System.get_env("REDIS_HOST", "localhost")
  defp redis_port, do: String.to_integer(System.get_env("REDIS_PORT", "6383"))
end
