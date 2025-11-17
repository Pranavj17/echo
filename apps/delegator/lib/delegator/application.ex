defmodule Delegator.Application do
  @moduledoc """
  OTP Application for the Delegator MCP Server.

  Starts and supervises:
  - SessionManager: Tracks active session state
  - MessageRouter: Routes messages to/from agents
  - AgentRegistry: ETS table initialization
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting Delegator application...")

    # Initialize AgentRegistry ETS table
    :ok = Delegator.AgentRegistry.init()

    children = [
      # Session state manager
      Delegator.SessionManager,

      # Message routing GenServer
      Delegator.MessageRouter
    ]

    opts = [strategy: :one_for_one, name: Delegator.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("Delegator application started successfully",
          supervisor_pid: inspect(pid)
        )

        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start Delegator application",
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end
end
