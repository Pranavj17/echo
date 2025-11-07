defmodule OperationsHead.CLI do
  @moduledoc """
  Escript entry point for the OPERATIONS_HEAD agent.

  Supports two modes:
  - MCP mode (default): Runs as MCP server listening on stdin/stdout
  - Autonomous mode (--autonomous): Runs indefinitely processing Redis messages
  """

  def main(args) do
    case args do
      ["--autonomous" | _] ->
        # Run in autonomous mode - start the OTP application and keep it alive
        IO.puts("Starting OPERATIONS_HEAD in autonomous mode...")

        # Start the shared infrastructure and agent application
        {:ok, _} = Application.ensure_all_started(:echo_shared)
        {:ok, _} = Application.ensure_all_started(:operations_head)

        IO.puts("OPERATIONS_HEAD application started successfully")
        Process.sleep(:infinity)

      _ ->
        # Run as MCP server
        OperationsHead.start()
    end
  end
end
