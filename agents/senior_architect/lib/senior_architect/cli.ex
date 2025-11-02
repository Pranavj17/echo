defmodule SeniorArchitect.CLI do
  @moduledoc """
  Escript entry point for the SENIOR_ARCHITECT MCP server.

  This module simply delegates to Senior_architect.start/0.
  """

  def main(_args) do
    Senior_architect.start()
  end
end
