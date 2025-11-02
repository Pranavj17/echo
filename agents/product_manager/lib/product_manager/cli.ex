defmodule ProductManager.CLI do
  @moduledoc """
  Escript entry point for the PRODUCT_MANAGER MCP server.

  This module simply delegates to Product_manager.start/0.
  """

  def main(_args) do
    Product_manager.start()
  end
end
