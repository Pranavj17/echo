# ECHO Shared Library

Common libraries and protocols for ECHO organizational agents.

## Overview

This library provides the foundation for all 9 ECHO agents:
- **MCP Protocol**: JSON-RPC 2.0 implementation for Claude Desktop integration
- **Database Schemas**: Shared PostgreSQL schemas for organizational data
- **Message Bus**: Redis pub/sub for real-time inter-agent communication
- **Base Server**: Common MCP server behavior for all agents

## Installation

In your agent's `mix.exs`:

```elixir
def deps do
  [
    {:echo_shared, path: "../shared"}
  ]
end
```

## Components

### 1. MCP Protocol (`EchoShared.MCP.Protocol`)

Implements JSON-RPC 2.0 for MCP communication:
- Request/response parsing
- Error handling
- Protocol validation

### 2. Base MCP Server (`EchoShared.MCP.Server`)

Base behavior for all ECHO agents:
```elixir
defmodule MyAgent do
  use EchoShared.MCP.Server

  @impl true
  def agent_info, do: %{name: "my-agent", version: "0.1.0", role: :my_role}

  @impl true
  def tools, do: [...]

  @impl true
  def execute_tool(name, args), do: {:ok, "result"}
end
```

### 3. Database Schemas

- `EchoShared.Schemas.Decision` - Organizational decisions
- `EchoShared.Schemas.Message` - Inter-agent messages
- `EchoShared.Schemas.Memory` - Shared knowledge base
- `EchoShared.Schemas.DecisionVote` - Collaborative voting
- `EchoShared.Schemas.AgentStatus` - Agent health monitoring

### 4. Message Bus (`EchoShared.MessageBus`)

Redis pub/sub for real-time communication:
```elixir
# Send message
MessageBus.publish_message(:ceo, :cto, :request, "Strategy Review", %{...})

# Subscribe to messages
MessageBus.subscribe_to_role(:ceo)
```

## Configuration

### Database

Set environment variables:
```bash
export DB_HOST=localhost
export DB_USER=postgres
export DB_PASSWORD=postgres
export DB_PORT=5432
```

### Redis

```bash
export REDIS_HOST=localhost
export REDIS_PORT=6379
```

## Development

```bash
# Install dependencies
cd shared
mix deps.get

# Run tests
mix test

# Generate docs
mix docs
```

## License

MIT License - see ../LICENSE
