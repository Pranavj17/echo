defmodule UiuxEngineer.CLI do
  @moduledoc """
  Escript entry point for the UIUX_ENGINEER MCP server.

  This module simply delegates to Uiux_engineer.start/0.
  """

  def main(_args) do
    Uiux_engineer.start()
  end
end
