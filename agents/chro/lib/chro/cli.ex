defmodule Chro.CLI do
  @moduledoc """
  Escript entry point for the CHRO MCP server.

  This module simply delegates to Chro.start/0.
  """

  def main(_args) do
    Chro.start()
  end
end
