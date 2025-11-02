defmodule TestLead.Application do
  @moduledoc """
  OTP Application for the TEST_LEAD agent.

  Starts the shared infrastructure (database, Redis) and TEST_LEAD-specific services.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting TEST_LEAD Agent...")

    children = [
      # Start shared infrastructure from EchoShared
      EchoShared.Repo,
      {Redix, name: :redix, host: redis_host(), port: redis_port()},
      {Redix.PubSub, name: :redix_pubsub, host: redis_host(), port: redis_port()},

      # TEST_LEAD-specific services
      Test_lead.DecisionEngine,
      Test_lead.MessageHandler
    ]

    opts = [strategy: :one_for_one, name: Test_lead.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis_host, do: System.get_env("REDIS_HOST", "localhost")
  defp redis_port, do: String.to_integer(System.get_env("REDIS_PORT", "6379"))
end
