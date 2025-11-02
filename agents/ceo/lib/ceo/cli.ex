defmodule Ceo.CLI do
  @moduledoc """
  Escript entry point for the CEO MCP server.

  This module simply delegates to Ceo.start/0.
  """

  def main(_args) do
    Ceo.start()
  end
end
