defmodule EchoShared do
  @moduledoc """
  ECHO Shared - Common libraries for ECHO organizational agents.

  This library provides:
  - MCP protocol implementation (JSON-RPC 2.0)
  - PostgreSQL storage for organizational memory
  - Redis message bus for inter-agent communication
  - Database schemas (decisions, messages, memories)
  - Base MCP server behavior

  ## Usage

  Each ECHO agent depends on this shared library:

      # In agent's mix.exs
      {:echo_shared, path: "../shared"}

  ## Architecture

  - **MCP Protocol**: JSON-RPC 2.0 over stdio for Claude Desktop
  - **Storage**: PostgreSQL with Ecto for persistence
  - **Message Bus**: Redis pub/sub for real-time coordination
  - **Schemas**: Shared data models across all agents
  """

  @version Mix.Project.config()[:version]

  @doc """
  Returns the version of ECHO Shared library.
  """
  def version, do: @version
end
