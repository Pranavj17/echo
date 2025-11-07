# agents/

**Context:** Agent Development & Implementation Patterns

This directory contains the 9 independent MCP server agents that form the ECHO organization. Each agent implements the MCP protocol and has specialized tools for their role.

## Purpose

Each agent is a standalone Elixir application that:
- Runs as an MCP server (JSON-RPC 2.0 over stdio)
- Can run in autonomous mode for testing/development
- Has specialized LLM integration via Ollama
- Communicates with other agents via Redis pub/sub
- Persists decisions and messages to PostgreSQL

## Directory Structure

```
agents/
├── claude.md                      # This file
├── ceo/                          # CEO agent (strategic leadership)
│   ├── lib/
│   │   ├── ceo.ex                # Main module with MCP tools
│   │   └── ceo/
│   │       ├── application.ex    # OTP application
│   │       ├── cli.ex            # Command-line interface
│   │       ├── decision_engine.ex # Decision logic
│   │       └── message_handler.ex # Message handling
│   ├── test/
│   ├── mix.exs                   # Dependencies + escript config
│   └── config/
│
├── cto/                          # CTO agent (technology strategy)
├── chro/                         # CHRO agent (human resources)
├── operations_head/              # Operations Head agent
├── product_manager/              # Product Manager agent
├── senior_architect/             # Senior Architect agent
├── uiux_engineer/                # UI/UX Engineer agent
├── senior_developer/             # Senior Developer agent
└── test_lead/                    # Test Lead agent
```

## Agent Implementation Pattern

All agents follow this standardized structure:

### 1. Main Module (`lib/{agent}.ex`)

```elixir
defmodule AgentName do
  use EchoShared.MCP.Server  # Provides MCP protocol handling

  @impl true
  def agent_info() do
    %{
      name: "agent-name",
      version: "1.0.0",
      role: :agent_role,
      llm_model: "model-name:version"
    }
  end

  @impl true
  def tools() do
    [
      %{
        name: "tool_name",
        description: "What this tool does",
        inputSchema: %{
          type: "object",
          properties: %{
            param: %{type: "string", description: "Parameter description"}
          },
          required: ["param"]
        }
      }
    ]
  end

  @impl true
  def execute_tool(tool_name, args) do
    case tool_name do
      "tool_name" ->
        with {:ok, validated} <- validate_args(args),
             {:ok, result} <- perform_action(validated) do
          {:ok, format_result(result)}
        else
          {:error, reason} -> {:error, "Tool execution failed: #{inspect(reason)}"}
        end

      _ ->
        {:error, "Unknown tool: #{tool_name}"}
    end
  end

  # Private helper functions
  defp validate_args(args), do: # validation logic
  defp perform_action(data), do: # business logic
  defp format_result(data), do: # format for MCP response
end
```

### 2. Application (`lib/{agent}/application.ex`)

```elixir
defmodule AgentName.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AgentName.MessageHandler,  # Subscribes to Redis channels
      # Add other supervised processes as needed
    ]

    opts = [strategy: :one_for_one, name: AgentName.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### 3. CLI (`lib/{agent}/cli.ex`)

```elixir
defmodule AgentName.CLI do
  def main(args) do
    case args do
      ["--autonomous"] ->
        # Run in standalone mode for testing
        AgentName.Application.start(:normal, [])
        Process.sleep(:infinity)

      [] ->
        # Run as MCP server (stdio mode)
        AgentName.start()

      _ ->
        IO.puts("Usage: agent_name [--autonomous]")
        System.halt(1)
    end
  end
end
```

### 4. Decision Engine (`lib/{agent}/decision_engine.ex`)

```elixir
defmodule AgentName.DecisionEngine do
  alias EchoShared.Schemas.Decision
  alias EchoShared.Repo

  def make_decision(decision_type, context) do
    mode = determine_mode(decision_type, context)

    case mode do
      :autonomous -> make_autonomous_decision(decision_type, context)
      :collaborative -> initiate_collaborative_decision(decision_type, context)
      :hierarchical -> escalate_decision(decision_type, context)
      :human -> request_human_approval(decision_type, context)
    end
  end

  defp determine_mode(decision_type, context) do
    # Logic to determine appropriate decision mode
    # based on agent authority and decision criticality
  end
end
```

### 5. Message Handler (`lib/{agent}/message_handler.ex`)

```elixir
defmodule AgentName.MessageHandler do
  use GenServer
  alias EchoShared.MessageBus

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Subscribe to agent's private channel
    MessageBus.subscribe("messages:agent_role")
    # Subscribe to broadcast channels
    MessageBus.subscribe("messages:all")
    MessageBus.subscribe("decisions:vote_required")

    {:ok, %{}}
  end

  @impl true
  def handle_info({:message, channel, payload}, state) do
    handle_message(channel, payload)
    {:noreply, state}
  end

  defp handle_message("messages:agent_role", %{type: :request} = message) do
    # Handle direct request
  end

  defp handle_message("decisions:vote_required", %{decision_id: id}) do
    # Handle voting request
  end
end
```

## Development Workflow

### Setting Up a New Agent

1. **Create directory structure**
   ```bash
   cd agents
   mix new agent_name
   cd agent_name
   ```

2. **Add dependencies in mix.exs**
   ```elixir
   defp deps do
     [
       {:echo_shared, path: "../../shared"}
     ]
   end
   ```

3. **Configure escript in mix.exs**
   ```elixir
   def project do
     [
       app: :agent_name,
       version: "1.0.0",
       escript: [main_module: AgentName.CLI]
     ]
   end
   ```

4. **Implement the 5 core modules** (see pattern above)

5. **Build and test**
   ```bash
   mix deps.get
   mix compile
   mix escript.build
   mix test
   ```

### Working on Existing Agent

```bash
cd agents/ceo

# Ensure shared library is compiled
cd ../../shared && mix compile && cd ../agents/ceo

# Get dependencies
mix deps.get

# Compile
mix compile

# Run tests
mix test

# Build executable
mix escript.build

# Run as MCP server (stdio mode)
./ceo

# Run in autonomous mode (testing)
./ceo --autonomous
```

## Agent-Specific LLM Models

Each agent has a specialized local LLM via Ollama:

| Agent | Model | Size | Purpose |
|-------|-------|------|---------|
| CEO | qwen2.5:14b | 14B | Strategic reasoning and leadership decisions |
| CTO | deepseek-coder:33b | 33B | Technical architecture and code evaluation |
| CHRO | llama3.1:8b | 8B | People management and communication |
| Operations Head | mistral:7b | 7B | Operations optimization and efficiency |
| Product Manager | llama3.1:8b | 8B | Product strategy and prioritization |
| Senior Architect | deepseek-coder:33b | 33B | System design and technical specifications |
| UI/UX Engineer | llama3.2-vision:11b | 11B | Design evaluation and visual understanding |
| Senior Developer | deepseek-coder:6.7b | 6.7B | Fast code generation and implementation |
| Test Lead | codellama:13b | 13B | Test generation and quality assurance |

### Using LLM in Agent Tools

All agents automatically have access to `ai_consult` tool:

```elixir
def execute_tool("ai_consult", %{"query_type" => type, "question" => question, "context" => context}) do
  alias EchoShared.LLM.DecisionHelper

  case DecisionHelper.consult(agent_role(), type, question, context) do
    {:ok, analysis} ->
      {:ok, %{
        analysis: analysis,
        model: get_llm_model(),
        timestamp: DateTime.utc_now()
      }}

    {:error, reason} ->
      {:error, "AI consultation failed: #{reason}"}
  end
end
```

## MCP Tool Design Guidelines

### Tool Naming Convention

- Use snake_case: `approve_budget`, `review_architecture`
- Be specific: `allocate_budget` not `manage_money`
- Action-oriented: `send_message` not `message`

### Input Schema Best Practices

```elixir
%{
  name: "tool_name",
  description: "Clear, concise description of what the tool does",
  inputSchema: %{
    type: "object",
    properties: %{
      # Required parameters first
      required_param: %{
        type: "string",
        description: "What this parameter is for",
        # Add constraints
        minLength: 1,
        maxLength: 255
      },
      # Optional parameters after
      optional_param: %{
        type: "number",
        description: "Optional parameter",
        default: 100
      },
      # Enums for constrained values
      status: %{
        type: "string",
        enum: ["pending", "approved", "rejected"],
        description: "Decision status"
      },
      # Nested objects
      context: %{
        type: "object",
        properties: %{
          budget: %{type: "number"},
          timeline: %{type: "string"}
        }
      }
    },
    required: ["required_param"]  # List required fields
  }
}
```

### Tool Execution Best Practices

```elixir
def execute_tool(tool_name, args) do
  # 1. Validate input
  with {:ok, validated} <- validate_input(args),
       # 2. Check agent authority
       {:ok, _} <- check_authority(validated),
       # 3. Perform business logic
       {:ok, result} <- perform_action(validated),
       # 4. Persist to database
       {:ok, record} <- persist_result(result),
       # 5. Notify other agents if needed
       :ok <- notify_agents(record) do
    # 6. Return formatted result
    {:ok, format_result(record)}
  else
    {:error, :unauthorized} ->
      {:error, "Agent lacks authority for this action"}

    {:error, :invalid_input, field} ->
      {:error, "Invalid input for field: #{field}"}

    {:error, reason} ->
      {:error, "Tool execution failed: #{inspect(reason)}"}
  end
end
```

## Common Patterns

### Pattern 1: Authority Check

```elixir
defp check_authority(%{amount: amount}) do
  limit = get_autonomous_limit()

  if amount <= limit do
    {:ok, :autonomous}
  else
    {:ok, :requires_escalation}
  end
end
```

### Pattern 2: Multi-Agent Coordination

```elixir
defp request_team_input(decision_id, participants) do
  Enum.each(participants, fn role ->
    MessageBus.publish_message(
      agent_role(),
      role,
      :request,
      "Input needed for decision #{decision_id}",
      %{decision_id: decision_id, deadline: calculate_deadline()}
    )
  end)
end
```

### Pattern 3: Error Recovery

```elixir
defp perform_action_with_retry(action, max_retries \\ 3) do
  retry(max_retries, fn ->
    case action.() do
      {:ok, result} -> {:ok, result}
      {:error, :timeout} -> {:retry, "Timeout, retrying..."}
      {:error, reason} -> {:error, reason}
    end
  end)
end
```

## Testing Agents

### Unit Tests (`test/{agent}_test.exs`)

```elixir
defmodule AgentNameTest do
  use ExUnit.Case
  alias AgentName

  describe "tools/0" do
    test "returns list of available tools" do
      tools = AgentName.tools()
      assert is_list(tools)
      assert Enum.all?(tools, fn tool ->
        Map.has_key?(tool, :name) and
        Map.has_key?(tool, :description) and
        Map.has_key?(tool, :inputSchema)
      end)
    end
  end

  describe "execute_tool/2" do
    test "executes valid tool with valid args" do
      args = %{"param" => "value"}
      assert {:ok, result} = AgentName.execute_tool("tool_name", args)
    end

    test "returns error for invalid tool" do
      assert {:error, _} = AgentName.execute_tool("invalid_tool", %{})
    end

    test "returns error for invalid args" do
      assert {:error, _} = AgentName.execute_tool("tool_name", %{})
    end
  end
end
```

### Integration Tests

See `../../test/integration/` for multi-agent workflow tests.

## Common Issues & Solutions

### Issue: Agent not receiving messages

**Symptom:** Messages sent but agent doesn't respond

**Debug:**
```bash
redis-cli
> SUBSCRIBE messages:agent_role
# Send test message from another agent
```

**Solution:** Ensure MessageHandler GenServer is started in Application supervision tree

### Issue: Database connection errors

**Symptom:** `(DBConnection.ConnectionError)`

**Debug:**
```bash
cd ../../shared
mix ecto.migrate
```

**Solution:** Ensure PostgreSQL is running and migrations are current

### Issue: LLM not responding

**Symptom:** `ai_consult` tool times out

**Debug:**
```bash
curl http://localhost:11434/api/tags
ollama list
```

**Solution:** Ensure Ollama is running and model is downloaded

### Issue: Compile errors after shared library update

**Symptom:** `(CompileError)`

**Solution:**
```bash
cd ../../shared && mix clean && mix compile
cd ../agents/agent_name && rm -rf _build deps && mix deps.get && mix compile
```

## Environment Variables

```bash
# Agent-specific model override
export CEO_MODEL=qwen2.5:14b

# Disable LLM for agent
export CEO_LLM_ENABLED=false

# Override Ollama endpoint
export OLLAMA_ENDPOINT=http://localhost:11434

# Authority limits
export CEO_BUDGET_LIMIT=1000000
export CTO_APPROVAL_REQUIRED_FOR=architecture,deployment

# Autonomous mode settings
export AGENT_AUTONOMOUS=true
export AGENT_LOG_LEVEL=debug
```

## Related Documentation

- **Parent:** [../CLAUDE.md](../CLAUDE.md) - Project overview
- **Dependencies:** [../shared/claude.md](../shared/claude.md) - Shared library usage
- **Workflows:** [../workflows/claude.md](../workflows/claude.md) - Multi-agent workflows
- **Testing:** [../training/claude.md](../training/claude.md) - Agent testing guide

## Critical Rules for Agent Development

1. **Always use `EchoShared.MCP.Server`** - Don't reimplement MCP protocol
2. **Validate all tool inputs** - Never trust MCP client input
3. **Check authority before actions** - Respect agent limits
4. **Persist to database** - All decisions and messages must be stored
5. **Use message bus** - Never create direct agent-to-agent connections
6. **Handle errors gracefully** - Return `{:error, reason}` tuples
7. **Test thoroughly** - Unit tests for all tools, integration tests for workflows
8. **Run with --autonomous for testing** - Don't test via stdio during development

---

**Remember:** Agents are independent but coordinated. Keep implementation simple and follow established patterns.
