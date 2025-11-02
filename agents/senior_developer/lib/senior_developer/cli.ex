defmodule SeniorDeveloper.CLI do
  @moduledoc """
  Escript entry point for the SENIOR_DEVELOPER MCP server.

  This module simply delegates to Senior_developer.start/0.
  """

  def main(_args) do
    Senior_developer.start()
  end
end
