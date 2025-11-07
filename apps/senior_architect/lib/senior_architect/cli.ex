defmodule SeniorArchitect.CLI do
  @moduledoc """
  Escript entry point for the SENIOR_ARCHITECT agent.

  Supports two modes:
  - MCP mode (default): Runs as MCP server listening on stdin/stdout
  - Autonomous mode (--autonomous): Runs indefinitely processing Redis messages
  """

  def main(args) do
    case args do
      ["--autonomous" | _] ->
        # Run in autonomous mode - start the OTP application and keep it alive
        IO.puts("Starting SENIOR_ARCHITECT in autonomous mode...")

        # Start the shared infrastructure and agent application
        {:ok, _} = Application.ensure_all_started(:echo_shared)
        {:ok, _} = Application.ensure_all_started(:senior_architect)

        IO.puts("SENIOR_ARCHITECT application started successfully")
        Process.sleep(:infinity)

      _ ->
        # Run as MCP server
        SeniorArchitect.start()
    end
  end
end
