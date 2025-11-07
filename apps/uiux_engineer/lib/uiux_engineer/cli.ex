defmodule UiuxEngineer.CLI do
  @moduledoc """
  Escript entry point for the UI_UX_ENGINEER agent.

  Supports two modes:
  - MCP mode (default): Runs as MCP server listening on stdin/stdout
  - Autonomous mode (--autonomous): Runs indefinitely processing Redis messages
  """

  def main(args) do
    case args do
      ["--autonomous" | _] ->
        # Run in autonomous mode - start the OTP application and keep it alive
        IO.puts("Starting UI_UX_ENGINEER in autonomous mode...")

        # Start the shared infrastructure and agent application
        {:ok, _} = Application.ensure_all_started(:echo_shared)
        {:ok, _} = Application.ensure_all_started(:uiux_engineer)

        IO.puts("UI_UX_ENGINEER application started successfully")
        Process.sleep(:infinity)

      _ ->
        # Run as MCP server
        UiuxEngineer.start()
    end
  end
end
