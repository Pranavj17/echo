defmodule OperationsHead.CLI do
  @moduledoc """
  Escript entry point for the OPERATIONS_HEAD MCP server.

  This module simply delegates to Operations_head.start/0.
  """

  def main(_args) do
    Operations_head.start()
  end
end
