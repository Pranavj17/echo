# LLM Session Integration Guide

**LocalCode-Style Conversation Memory for All ECHO Agents**

This guide shows how to integrate session-based LLM queries (like LocalCode) into all 9 ECHO agents.

## What You Get

✅ **Conversation Memory** - Multi-turn conversations with last 5 turns kept
✅ **Automatic Context Injection** - Agent role, recent decisions/messages, system status, git context
✅ **Context Size Warnings** - Alerts when context grows large (>4000 tokens)
✅ **Session Management** - Auto-cleanup after 1 hour of inactivity
✅ **Project-Aware Responses** - LLM knows about ECHO architecture and current state

## Architecture

```
Agent MCP Tool: session_consult
       ↓
DecisionHelper.consult_session(role, session_id, question)
       ↓
Session.query(session_id, question, opts)
       ├─ ContextBuilder.build_startup_context(role)
       ├─ Maintains conversation history (last 5 turns)
       └─ Client.chat(model, messages, opts)
```

## How to Add to Any Agent

### Step 1: Add `session_consult` Tool Definition

In your agent's main module (e.g., `apps/echo_ceo/lib/ceo.ex`):

```elixir
defmodule CEO do
  use EchoShared.MCP.Server

  @impl true
  def tools do
    [
      # ... existing tools ...

      # NEW: Session-based AI consultation with conversation memory
      %{
        name: "session_consult",
        description: """
        Query the AI assistant with conversation memory (LocalCode-style).

        Maintains multi-turn conversations with automatic context injection:
        - Your role and responsibilities
        - Recent decisions and messages
        - System status and git context
        - Conversation history (last 5 turns)

        Use this for exploratory questions, decision analysis, or iterative thinking.
        """,
        inputSchema: %{
          type: "object",
          properties: %{
            question: %{
              type: "string",
              description: "The question to ask the AI assistant"
            },
            session_id: %{
              type: "string",
              description: "Session ID to continue conversation (optional, omit for new session)"
            },
            context: %{
              type: "string",
              description: "Additional context for this specific query (optional)"
            }
          },
          required: ["question"]
        }
      }
    ]
  end

  @impl true
  def execute_tool(tool_name, args) do
    case tool_name do
      # ... existing tools ...

      "session_consult" ->
        execute_session_consult(args)

      _ ->
        {:error, "Unknown tool: #{tool_name}"}
    end
  end

  # NEW: Execute session-based consultation
  defp execute_session_consult(args) do
    alias EchoShared.LLM.DecisionHelper

    question = Map.fetch!(args, "question")
    session_id = Map.get(args, "session_id")  # nil for new session
    context = Map.get(args, "context")

    # Build opts
    opts = if context, do: [context: context], else: []

    case DecisionHelper.consult_session(agent_role(), session_id, question, opts) do
      {:ok, result} ->
        # Format response with warnings
        response = format_session_response(result)
        {:ok, response}

      {:error, :llm_disabled} ->
        {:error, "LLM is disabled for #{agent_role()}. Enable with LLM_ENABLED=true"}

      {:error, :session_not_found} ->
        {:error, "Session not found: #{session_id}. It may have expired."}

      {:error, reason} ->
        {:error, "AI consultation failed: #{inspect(reason)}"}
    end
  end

  defp format_session_response(result) do
    base = %{
      response: result.response,
      session_id: result.session_id,
      turn_count: result.turn_count,
      estimated_tokens: result.total_tokens,
      model: EchoShared.LLM.Config.get_model(agent_role())
    }

    # Add warnings if any
    if result.warnings != [] do
      Map.put(base, :warnings, result.warnings)
    else
      base
    end
  end

  # Helper to get agent role
  defp agent_role, do: :ceo  # Change per agent: :ceo, :cto, :chro, etc.
end
```

### Step 2: Update `agent_role()` Helper

Make sure each agent returns its correct role:

```elixir
# CEO agent
defp agent_role, do: :ceo

# CTO agent
defp agent_role, do: :cto

# CHRO agent
defp agent_role, do: :chro

# Operations Head agent
defp agent_role, do: :operations_head

# Product Manager agent
defp agent_role, do: :product_manager

# Senior Architect agent
defp agent_role, do: :senior_architect

# UI/UX Engineer agent
defp agent_role, do: :uiux_engineer

# Senior Developer agent
defp agent_role, do: :senior_developer

# Test Lead agent
defp agent_role, do: :test_lead
```

### Step 3: Rebuild Agent

```bash
cd apps/echo_ceo  # Or whichever agent you're updating
mix deps.get
mix compile
mix escript.build
```

## Usage Examples

### Example 1: New Session Query

```bash
# Via MCP client (Claude Desktop)
{
  "tool": "session_consult",
  "arguments": {
    "question": "What are my top priorities as CEO this quarter?"
  }
}

# Response
{
  "response": "As CEO, your top priorities should be:\n1. Strategic planning...",
  "session_id": "ceo_1699564234_123456",
  "turn_count": 1,
  "estimated_tokens": 1876,
  "model": "llama3.1:8b"
}
```

### Example 2: Continue Conversation

```bash
# Follow-up query using session_id
{
  "tool": "session_consult",
  "arguments": {
    "session_id": "ceo_1699564234_123456",
    "question": "Tell me more about priority #2"
  }
}

# Response
{
  "response": "Regarding strategic planning, you should focus on...",
  "session_id": "ceo_1699564234_123456",
  "turn_count": 2,
  "estimated_tokens": 2341,
  "model": "llama3.1:8b"
}
```

### Example 3: With Additional Context

```bash
{
  "tool": "session_consult",
  "arguments": {
    "question": "Should we approve this budget request?",
    "context": "Budget request: $2.5M for new datacenter. Current cash reserves: $10M."
  }
}
```

### Example 4: Context Warning

```bash
# After 8-10 turns...
{
  "response": "Based on our previous discussion...",
  "session_id": "ceo_1699564234_123456",
  "turn_count": 9,
  "estimated_tokens": 4523,
  "model": "llama3.1:8b",
  "warnings": [
    "Session has 9 turns. Consider ending session soon.",
    "Context size large (4523 tokens). Session approaching limit."
  ]
}
```

## What Gets Injected Automatically

When you start a session, the LLM automatically receives:

### 1. Project Overview (~400 tokens)
- ECHO architecture explanation
- 9 agent roles
- Technology stack (Elixir, PostgreSQL, Redis, MCP)
- Decision modes (Autonomous, Collaborative, Hierarchical, Human)

### 2. Agent Role Context (~300 tokens)
- Your title (e.g., "Chief Executive Officer")
- Your responsibilities (e.g., "Strategic leadership", "Budget approvals")
- Your authority limits (e.g., "Can approve up to $1M autonomously")
- Your key collaborators (e.g., [:cto, :chro, :operations_head])

### 3. System Status (~200 tokens)
- PostgreSQL status
- Redis status
- Ollama status
- Active agents count

### 4. Recent Activity (~500-800 tokens)
- Last 5 decisions you initiated
- Last 5 messages to/from you

### 5. Git Context (~100 tokens)
- Current branch
- Last commit

### 6. Conversation History (~500-2000 tokens, grows over time)
- Last 5 conversation turns
- Your questions + AI responses

**Total startup context:** ~1,500-2,000 tokens
**After 5 turns:** ~3,000-4,000 tokens
**Warning threshold:** 4,000 tokens
**Limit:** 6,000 tokens (session restart recommended)

## Session Management

### Automatic Cleanup

Sessions are automatically cleaned up after:
- **1 hour of inactivity** (no queries)
- Configurable in `apps/echo_shared/config/dev.exs`

### Manual Session Control

```elixir
# List all active sessions
EchoShared.LLM.Session.list_sessions()
# => [
#   %{session_id: "ceo_...", agent_role: :ceo, turn_count: 5, ...},
#   %{session_id: "cto_...", agent_role: :cto, turn_count: 2, ...}
# ]

# Get session details
EchoShared.LLM.Session.get_session("ceo_1699564234_123456")
# => %{session_id: ..., conversation_history: [...], ...}

# End session manually
EchoShared.LLM.Session.end_session("ceo_1699564234_123456")
# => {:ok, archived_conversation}
```

## Configuration

All configuration in `apps/echo_shared/config/dev.exs`:

```elixir
# LLM Session configuration
config :echo_shared, :llm_session,
  max_turns: 5,                    # Conversation history depth
  timeout_ms: 3_600_000,           # 1 hour inactivity timeout
  cleanup_interval_ms: 900_000,    # Cleanup every 15 minutes
  warning_threshold: 4_000,        # Warn at 4K tokens
  limit_threshold: 6_000           # Critical at 6K tokens

# Agent-specific models
config :echo_shared, :agent_models, %{
  ceo: "llama3.1:8b",
  cto: "deepseek-coder:6.7b",
  chro: "llama3.1:8b",
  operations_head: "mistral:7b",
  product_manager: "llama3.1:8b",
  senior_architect: "deepseek-coder:6.7b",
  uiux_engineer: "llama3.1:8b",
  senior_developer: "deepseek-coder:6.7b",
  test_lead: "deepseek-coder:6.7b"
}
```

### Override via Environment Variables

```bash
# Change CEO's model
export CEO_MODEL=qwen2.5:14b

# Disable LLM for specific agent
export CEO_LLM_ENABLED=false

# Change Ollama endpoint
export OLLAMA_ENDPOINT=http://192.168.1.100:11434
```

## Comparison: LocalCode vs Agent Session Integration

| Feature | LocalCode (Bash) | Agent LLM (Elixir) |
|---------|------------------|---------------------|
| **Session Management** | ✅ File-based | ✅ ETS-based (in-memory) |
| **Context Injection** | ✅ CLAUDE.md + git + status | ✅ Role + decisions + messages + git |
| **Conversation Memory** | ✅ Last 5 turns | ✅ Last 5 turns |
| **Context Warnings** | ✅ Yes | ✅ Yes |
| **Auto-Cleanup** | ❌ Manual (`lc_end`) | ✅ Automatic (1 hour timeout) |
| **Tool Simulation** | ✅ Yes (bash) | ❌ No (could add) |
| **Model** | deepseek-coder:6.7b | Role-specific (9 models) |
| **Response Time** | 7-30 seconds | 7-30 seconds |
| **Use Case** | CLI development assistant | Agent decision support |

## Testing

### Unit Test Example

```elixir
defmodule CEOTest do
  use ExUnit.Case
  alias CEO

  describe "session_consult tool" do
    test "starts new session and returns response" do
      args = %{"question" => "What should I prioritize?"}

      assert {:ok, result} = CEO.execute_tool("session_consult", args)
      assert is_binary(result.response)
      assert is_binary(result.session_id)
      assert result.turn_count == 1
      assert result.model == "llama3.1:8b"
    end

    test "continues existing session" do
      # First query
      {:ok, result1} = CEO.execute_tool("session_consult", %{
        "question" => "What's my role?"
      })

      # Second query with session_id
      {:ok, result2} = CEO.execute_tool("session_consult", %{
        "session_id" => result1.session_id,
        "question" => "Tell me more"
      })

      assert result2.session_id == result1.session_id
      assert result2.turn_count == 2
    end

    test "returns error for invalid session" do
      args = %{
        "session_id" => "invalid_session_123",
        "question" => "Test"
      }

      assert {:error, message} = CEO.execute_tool("session_consult", args)
      assert message =~ "Session not found"
    end
  end
end
```

### Integration Test

```bash
# Start agent in autonomous mode
cd apps/echo_ceo
./ceo --autonomous &
CEO_PID=$!

# Test session_consult via IEx
iex -S mix

iex> alias EchoShared.LLM.DecisionHelper
iex> {:ok, r1} = DecisionHelper.consult_session(:ceo, nil, "What's my role?")
iex> IO.puts(r1.response)
iex> {:ok, r2} = DecisionHelper.consult_session(:ceo, r1.session_id, "What are my priorities?")
iex> IO.puts(r2.response)
iex> EchoShared.LLM.Session.end_session(r1.session_id)

# Cleanup
kill $CEO_PID
```

## Troubleshooting

### "LLM is disabled"

```bash
# Enable globally
export LLM_ENABLED=true

# Or per-agent
export CEO_LLM_ENABLED=true
```

### "Session not found"

Sessions expire after 1 hour of inactivity. Start a new session by omitting `session_id`.

### "Failed to get response from Ollama"

```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Check model is installed
ollama list | grep llama3.1

# Pull model if missing
ollama pull llama3.1:8b
```

### Slow responses (>60 seconds)

```bash
# Use smaller/faster model
export CEO_MODEL=deepseek-coder:1.3b

# Or increase timeout in client.ex (default: 180 seconds)
```

## Next Steps

1. **Add to all 9 agents** - Copy the pattern to each agent module
2. **Test each agent** - Verify LLM responds correctly for each role
3. **Monitor performance** - Track response times and context sizes
4. **Optimize prompts** - Refine system prompts in `Config.get_system_prompt/1`
5. **Add tool simulation** (optional) - Similar to LocalCode's tool detection

## Related Files

- `apps/echo_shared/lib/echo_shared/llm/session.ex` - Session manager
- `apps/echo_shared/lib/echo_shared/llm/context_builder.ex` - Context injection
- `apps/echo_shared/lib/echo_shared/llm/decision_helper.ex` - High-level API
- `apps/echo_shared/lib/echo_shared/llm/config.ex` - Model configuration
- `apps/echo_shared/lib/echo_shared/llm/client.ex` - Ollama HTTP client
- `apps/echo_shared/config/dev.exs` - Configuration

## Summary

You now have **LocalCode-style conversation memory** for all ECHO agents! Each agent can:

✅ Have multi-turn conversations with project context
✅ Remember last 5 turns automatically
✅ Get warnings when context grows large
✅ Auto-cleanup inactive sessions
✅ Use role-specific specialized models

**Integration effort:** ~50 lines of code per agent
**Benefits:** Project-aware AI assistance for autonomous decision-making
**Response quality:** Comparable to LocalCode, specialized per agent role

Happy integrating! 🚀
