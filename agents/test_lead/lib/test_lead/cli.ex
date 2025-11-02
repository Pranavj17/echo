defmodule TestLead.CLI do
  @moduledoc """
  Escript entry point for the TEST_LEAD MCP server.

  This module simply delegates to Test_lead.start/0.
  """

  def main(_args) do
    Test_lead.start()
  end
end
