defmodule SeniorDeveloper.CLI do
  @moduledoc """
  Escript entry point for the SENIOR_DEVELOPER agent.

  Supports two modes:
  - MCP mode (default): Runs as MCP server listening on stdin/stdout
  - Autonomous mode (--autonomous): Runs indefinitely processing Redis messages
  """

  def main(args) do
    case args do
      ["--autonomous" | _] ->
        # Run in autonomous mode - start the OTP application and keep it alive
        IO.puts("Starting SENIOR_DEVELOPER in autonomous mode...")

        # Start the shared infrastructure and agent application
        {:ok, _} = Application.ensure_all_started(:echo_shared)
        {:ok, _} = Application.ensure_all_started(:senior_developer)

        IO.puts("SENIOR_DEVELOPER application started successfully")
        Process.sleep(:infinity)

      _ ->
        # Run as MCP server
        SeniorDeveloper.start()
    end
  end
end
