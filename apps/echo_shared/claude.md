# shared/

**Context:** Shared Library & Core Infrastructure

This directory contains the foundational library used by all ECHO agents. It provides MCP protocol implementation, database access, message bus, LLM integration, and workflow engine.

## Purpose

The shared library provides:
- **MCP Protocol** - Base server behavior and JSON-RPC 2.0 implementation
- **Database Layer** - Ecto schemas and repository for PostgreSQL
- **Message Bus** - Redis pub/sub wrapper for inter-agent communication
- **LLM Integration** - Ollama client and decision helpers
- **Workflow Engine** - Multi-agent workflow orchestration
- **Common Utilities** - Shared functions used across all agents

## Directory Structure

```
shared/
├── claude.md                       # This file
├── mix.exs                        # Library dependencies and configuration
├── lib/
│   ├── echo_shared.ex             # Main module
│   ├── echo_shared/
│   │   ├── mcp/
│   │   │   ├── server.ex          # Base MCP server behavior
│   │   │   └── protocol.ex        # JSON-RPC 2.0 implementation
│   │   ├── schemas/
│   │   │   ├── decision.ex        # Decision schema and changeset
│   │   │   ├── message.ex         # Message schema
│   │   │   ├── memory.ex          # Memory schema
│   │   │   ├── decision_vote.ex   # Vote schema
│   │   │   └── agent_status.ex    # Agent health schema
│   │   ├── llm/
│   │   │   ├── client.ex          # Ollama HTTP client
│   │   │   ├── config.ex          # Model configuration
│   │   │   └── decision_helper.ex # AI consultation helpers
│   │   ├── workflow/
│   │   │   ├── definition.ex      # Workflow DSL
│   │   │   ├── engine.ex          # Workflow execution engine
│   │   │   └── execution.ex       # Execution state tracking
│   │   ├── message_bus.ex         # Redis pub/sub wrapper
│   │   ├── repo.ex                # Ecto repository
│   │   ├── agent_health_monitor.ex # Health checking
│   │   ├── participation_evaluator.ex # Decision participation logic
│   │   └── application.ex         # OTP application
│   └
├── priv/
│   └── repo/
│       └── migrations/            # Database migrations
├── test/
│   └── echo_shared/              # Unit tests
└── config/
    ├── config.exs                # Shared configuration
    └── test.exs                  # Test configuration
```

## Core Modules

### EchoShared.MCP.Server

**Purpose:** Base behavior for all agent MCP servers

**Usage:**
```elixir
defmodule MyAgent do
  use EchoShared.MCP.Server

  @impl true
  def agent_info() do
    %{
      name: "my-agent",
      version: "1.0.0",
      role: :my_agent,
      llm_model: "model-name:version"
    }
  end

  @impl true
  def tools() do
    [
      %{name: "tool_name", description: "...", inputSchema: %{...}}
    ]
  end

  @impl true
  def execute_tool(name, args) do
    # Tool implementation
    {:ok, result}
  end
end
```

**Callbacks:**
- `agent_info/0` - Returns agent metadata
- `tools/0` - Returns list of MCP tools
- `execute_tool/2` - Executes a tool with arguments
- `resources/0` - (Optional) Returns available resources
- `prompts/0` - (Optional) Returns available prompts

**Provided Functions:**
- `start/0` - Starts MCP server loop (stdio mode)
- `handle_request/1` - Processes JSON-RPC requests
- `send_response/1` - Sends JSON-RPC responses

### EchoShared.MCP.Protocol

**Purpose:** JSON-RPC 2.0 protocol implementation

**Methods:**
```elixir
# Initialize connection
Protocol.initialize(client_info, server_capabilities)

# List tools
Protocol.tools_list()

# Call tool
Protocol.tools_call(tool_name, args)

# Send notification (no response expected)
Protocol.notification(method, params)

# Error response
Protocol.error(request_id, code, message, data \\ nil)
```

**Error Codes:**
- `-32700` - Parse error (invalid JSON)
- `-32600` - Invalid request
- `-32601` - Method not found
- `-32602` - Invalid params
- `-32603` - Internal error

### EchoShared.Repo

**Purpose:** Ecto repository for PostgreSQL database access

**Configuration:**
```elixir
# config/config.exs
config :echo_shared, EchoShared.Repo,
  database: "echo_org",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432
```

**Usage:**
```elixir
alias EchoShared.Repo
alias EchoShared.Schemas.Decision

# Query
decision = Repo.get(Decision, id)
decisions = Repo.all(Decision)

# Query with filter
Repo.all(from d in Decision, where: d.status == "pending")

# Insert
%Decision{}
|> Decision.changeset(attrs)
|> Repo.insert()

# Update
decision
|> Decision.changeset(changes)
|> Repo.update()

# Delete
Repo.delete(decision)

# Transaction
Repo.transaction(fn ->
  # Multiple operations
  {:ok, decision} = insert_decision()
  {:ok, votes} = insert_votes()
  {decision, votes}
end)
```

## Database Schemas

### EchoShared.Schemas.Decision

**Table:** `decisions`

**Fields:**
- `id` (UUID) - Primary key
- `decision_type` (string) - Type of decision (e.g., "budget_approval", "architecture_review")
- `initiator_role` (string) - Agent that initiated the decision
- `participants` (JSONB) - List of participating agents
- `mode` (string) - Decision mode: "autonomous", "collaborative", "hierarchical", "human"
- `context` (JSONB) - Decision context and parameters
- `status` (string) - "pending", "approved", "rejected", "escalated"
- `consensus_score` (float) - Voting consensus (0.0 - 1.0)
- `outcome` (JSONB) - Decision result
- `created_at` (timestamp) - When decision was created
- `completed_at` (timestamp) - When decision was finalized

**Changeset:**
```elixir
Decision.changeset(%Decision{}, %{
  decision_type: "budget_approval",
  initiator_role: "ceo",
  participants: ["ceo", "cto", "operations_head"],
  mode: "collaborative",
  context: %{amount: 500_000, purpose: "New datacenter"},
  status: "pending"
})
```

### EchoShared.Schemas.Message

**Table:** `messages`

**Fields:**
- `id` (bigserial) - Primary key
- `from_role` (string) - Sender agent
- `to_role` (string) - Recipient agent
- `type` (string) - "request", "response", "notification", "escalation"
- `subject` (string) - Message subject
- `content` (JSONB) - Message content
- `metadata` (JSONB) - Additional metadata
- `read` (boolean) - Read status
- `created_at` (timestamp) - When message was sent

**Changeset:**
```elixir
Message.changeset(%Message{}, %{
  from_role: "ceo",
  to_role: "cto",
  type: "request",
  subject: "Q3 Technology Strategy Review",
  content: %{question: "What are top 3 priorities?", deadline: "2025-11-10"}
})
```

### EchoShared.Schemas.Memory

**Table:** `memories`

**Fields:**
- `id` (UUID) - Primary key
- `key` (string, unique) - Memory key
- `content` (text) - Memory content
- `tags` (text array) - Searchable tags
- `metadata` (JSONB) - Additional metadata
- `created_by_role` (string) - Agent that created memory
- `inserted_at` (timestamp) - Creation time
- `updated_at` (timestamp) - Last update time

**Changeset:**
```elixir
Memory.changeset(%Memory{}, %{
  key: "company_mission",
  content: "Build the future of AI-powered organizations",
  tags: ["mission", "vision", "strategic"],
  created_by_role: "ceo"
})
```

### EchoShared.Schemas.DecisionVote

**Table:** `decision_votes`

**Fields:**
- `id` (bigserial) - Primary key
- `decision_id` (UUID) - References decisions(id)
- `voter_role` (string) - Agent voting
- `vote` (string) - "approve", "reject", "abstain"
- `rationale` (text) - Reason for vote
- `confidence` (float) - Vote confidence (0.0 - 1.0)
- `voted_at` (timestamp) - Vote timestamp

### EchoShared.Schemas.AgentStatus

**Table:** `agent_status`

**Fields:**
- `role` (string) - Primary key
- `status` (string) - "running", "stopped", "error"
- `last_heartbeat` (timestamp) - Last health check
- `version` (string) - Agent version
- `capabilities` (JSONB) - Agent capabilities
- `metadata` (JSONB) - Additional info

## Message Bus (Redis)

### EchoShared.MessageBus

**Purpose:** Redis pub/sub wrapper for inter-agent communication

**Channel Naming:**
- `messages:{role}` - Private per-agent channel
- `messages:all` - Broadcast to all agents
- `messages:leadership` - C-suite only
- `decisions:new` - New decision events
- `decisions:vote_required` - Voting requests
- `decisions:completed` - Decision finalized
- `decisions:escalated` - Escalation events
- `agents:heartbeat` - Health monitoring

**Usage:**
```elixir
alias EchoShared.MessageBus

# Subscribe to channel (in GenServer)
def init(_) do
  MessageBus.subscribe("messages:ceo")
  MessageBus.subscribe("messages:all")
  {:ok, %{}}
end

# Handle received message
def handle_info({:message, channel, payload}, state) do
  # Process message
  {:noreply, state}
end

# Publish message
MessageBus.publish_message(
  from_role: "ceo",
  to_role: "cto",
  type: :request,
  subject: "Architecture review needed",
  content: %{design_doc_url: "..."}
)

# Broadcast to all agents
MessageBus.broadcast_message(
  from_role: "ceo",
  type: :notification,
  subject: "All-hands announcement",
  content: %{message: "Q3 results are excellent!"}
)

# Publish decision event
MessageBus.publish_decision_event(:new, %{
  decision_id: decision_id,
  decision_type: "budget_approval",
  initiator: "ceo"
})
```

## LLM Integration

### EchoShared.LLM.Client

**Purpose:** HTTP client for Ollama API

**Configuration:**
```elixir
# config/config.exs
config :echo_shared, :ollama,
  endpoint: "http://localhost:11434",
  timeout: 30_000
```

**Usage:**
```elixir
alias EchoShared.LLM.Client

# Generate completion
{:ok, response} = Client.generate(
  model: "qwen2.5:14b",
  prompt: "Should we expand to European market?",
  context: %{budget: "$5M", timeline: "12 months"}
)

# Stream completion
Client.generate_stream(
  model: "deepseek-coder:33b",
  prompt: "Review this architecture design...",
  callback: fn chunk -> IO.write(chunk) end
)

# List available models
{:ok, models} = Client.list_models()
```

### EchoShared.LLM.Config

**Purpose:** Model configuration per agent role

**Models:**
```elixir
Config.get_model_for_role(:ceo)              # => "qwen2.5:14b"
Config.get_model_for_role(:cto)              # => "deepseek-coder:33b"
Config.get_model_for_role(:senior_developer) # => "deepseek-coder:6.7b"
```

### EchoShared.LLM.DecisionHelper

**Purpose:** High-level AI consultation functions

**Usage:**
```elixir
alias EchoShared.LLM.DecisionHelper

# Consult AI for decision analysis
{:ok, analysis} = DecisionHelper.consult(
  agent_role: :ceo,
  query_type: :decision_analysis,
  question: "Should we acquire CompanyX?",
  context: %{
    price: "$50M",
    revenue: "$10M/year",
    synergies: ["Technology stack", "Customer base"]
  }
)

# Get AI recommendation
{:ok, recommendation} = DecisionHelper.recommend(
  agent_role: :product_manager,
  scenario: :feature_prioritization,
  options: ["Feature A", "Feature B", "Feature C"],
  criteria: %{
    business_value: "high",
    implementation_cost: "medium",
    user_demand: "very_high"
  }
)
```

## Workflow Engine

### EchoShared.Workflow.Definition

**Purpose:** Define multi-agent workflows using DSL

**Example:**
```elixir
alias EchoShared.Workflow.Definition

Definition.new(
  "feature_development",
  "Complete feature development workflow",
  [:product_manager, :senior_architect, :cto, :senior_developer, :test_lead, :ceo],
  [
    # Step 1: PM defines requirements
    {:request, :product_manager, "define_feature", %{
      name: "User authentication",
      priority: "high"
    }},

    # Step 2: Architect designs system
    {:request, :senior_architect, "design_system", %{
      requirements: :from_previous_step
    }},

    # Step 3: CTO approves architecture
    {:decision, %{
      type: "architecture_approval",
      mode: :autonomous,
      initiator: :cto
    }},

    # Step 4: Parallel implementation
    {:parallel, [
      {:request, :senior_developer, "implement_backend", %{}},
      {:request, :ui_ux_engineer, "design_ui", %{}}
    ]},

    # Step 5: Test lead creates test plan
    {:request, :test_lead, "create_test_plan", %{}},

    # Step 6: CEO approves budget
    {:decision, %{
      type: "budget_approval",
      mode: :autonomous,
      initiator: :ceo
    }},

    # Step 7: Human approval for deployment
    {:pause, "Human approval required for production deployment"}
  ]
)
```

### EchoShared.Workflow.Engine

**Purpose:** Execute workflows

**Usage:**
```elixir
alias EchoShared.Workflow.Engine

# Start workflow execution
{:ok, execution_id} = Engine.start_workflow(workflow_definition, %{
  triggered_by: "ceo",
  context: %{epic_id: "EPIC-123"}
})

# Check workflow status
{:ok, status} = Engine.get_status(execution_id)
# => %{
#   status: "running",
#   current_step: 3,
#   total_steps: 7,
#   completed_steps: 2
# }

# Resume paused workflow
Engine.resume(execution_id, %{human_approval: true})

# Cancel workflow
Engine.cancel(execution_id, "Requirements changed")
```

## Utilities

### EchoShared.AgentHealthMonitor

**Purpose:** Monitor agent health and heartbeats

**Usage:**
```elixir
alias EchoShared.AgentHealthMonitor

# Record heartbeat
AgentHealthMonitor.heartbeat(:ceo, %{
  version: "1.0.0",
  uptime: 3600,
  memory_mb: 125
})

# Check if agent is healthy
AgentHealthMonitor.healthy?(:ceo)  # => true

# Get all agent statuses
AgentHealthMonitor.get_all_statuses()
# => [
#   %{role: :ceo, status: "running", last_heartbeat: ~U[...]},
#   %{role: :cto, status: "running", last_heartbeat: ~U[...]},
#   ...
# ]
```

### EchoShared.ParticipationEvaluator

**Purpose:** Determine which agents should participate in decisions

**Usage:**
```elixir
alias EchoShared.ParticipationEvaluator

# Get participants for decision type
participants = ParticipationEvaluator.get_participants(
  decision_type: "architecture_review",
  initiator: :senior_architect,
  context: %{scope: "system_wide"}
)
# => [:cto, :senior_architect, :operations_head]

# Check if agent should be involved
ParticipationEvaluator.should_participate?(
  agent: :ceo,
  decision_type: "budget_approval",
  context: %{amount: 2_000_000}
)
# => true (amount exceeds autonomous limit)
```

## Database Migrations

### Creating Migrations

```bash
cd shared
mix ecto.gen.migration add_field_to_table
```

### Migration Example

```elixir
defmodule EchoShared.Repo.Migrations.AddFieldToTable do
  use Ecto.Migration

  def change do
    alter table(:decisions) do
      add :new_field, :string
    end

    create index(:decisions, [:new_field])
  end
end
```

### Running Migrations

```bash
cd shared
mix ecto.migrate          # Apply migrations
mix ecto.rollback         # Rollback last migration
mix ecto.rollback --step 3 # Rollback 3 migrations
```

## Testing

### Running Tests

```bash
cd shared
mix test                  # All tests
mix test test/echo_shared/mcp/server_test.exs  # Specific file
mix test --only unit      # Tagged tests
```

### Test Example

```elixir
defmodule EchoShared.MessageBusTest do
  use ExUnit.Case
  alias EchoShared.MessageBus

  setup do
    # Setup test fixtures
    :ok
  end

  describe "publish_message/1" do
    test "publishes message to correct channel" do
      assert :ok = MessageBus.publish_message(
        from_role: "ceo",
        to_role: "cto",
        type: :request,
        subject: "Test",
        content: %{test: true}
      )
    end
  end
end
```

## Environment Variables

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=echo_org
DB_USER=postgres
DB_PASSWORD=postgres

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0

# Ollama
OLLAMA_ENDPOINT=http://localhost:11434
OLLAMA_TIMEOUT=30000

# MCP
MCP_LOG_LEVEL=info
MCP_PROTOCOL_VERSION=2024-11-05
```

## Common Issues

### Database connection errors

```bash
# Check PostgreSQL is running
psql -U postgres -c "SELECT 1"

# Run migrations
cd shared && mix ecto.migrate
```

### Redis connection errors

```bash
# Check Redis is running
redis-cli ping  # Should return PONG

# Test connection
redis-cli
> SET test_key "test_value"
> GET test_key
```

### Compilation errors

```bash
# Clean and recompile
cd shared
mix clean
mix deps.clean --all
mix deps.get
mix compile
```

## Using LocalCode for Shared Library Development

**LocalCode** (scripts/llm/) provides quick assistance when working with the shared library. See `../CLAUDE.md` Rule 8 for complete documentation.

### Quick Queries

```bash
source ./scripts/llm/localcode_quick.sh
lc_start

# Understanding modules
lc_query "How does EchoShared.MessageBus work?"
lc_query "Explain the MCP.Server behavior"
lc_query "What schemas are available?"

# Implementation help
lc_query "How do I create a new database migration?"
lc_query "Show me the pattern for Redis pub/sub"
lc_query "How to use the LLM.DecisionHelper module?"

lc_end
```

**Use LocalCode for:**
- Quick API reference lookups
- Understanding module interactions
- Debugging hints for compilation errors
- Schema and migration patterns

**Use Claude Code for:**
- Implementing new shared functionality
- Refactoring modules
- Writing tests
- Database migrations

Response time: 7-30 seconds typical

## Related Documentation

- **Parent:** [../CLAUDE.md](../CLAUDE.md) - Project overview
- **Agents:** [../agents/claude.md](../agents/claude.md) - Agent development guide
- **Workflows:** [../workflows/claude.md](../workflows/claude.md) - Workflow patterns
- **Testing:** [../training/claude.md](../training/claude.md) - Testing guide

---

**Remember:** The shared library is the foundation. Keep it stable, well-tested, and backward-compatible.
