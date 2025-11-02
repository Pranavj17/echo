defmodule Cto.CLI do
  @moduledoc """
  Escript entry point for the CTO MCP server.

  This module simply delegates to Cto.start/0.
  """

  def main(_args) do
    Cto.start()
  end
end
