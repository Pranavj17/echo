# Copy this into any ECHO agent to add session-based LLM consultation
# Replace AGENT_NAME and :agent_role with your agent's details

defmodule AGENT_NAME do
  use EchoShared.MCP.Server

  @impl true
  def agent_info do
    %{
      name: "agent-name",
      version: "1.0.0",
      role: :agent_role,  # ← Change this: :ceo, :cto, :chro, etc.
      llm_model: "model-name:version"
    }
  end

  @impl true
  def tools do
    [
      # ... your existing tools ...

      # ============================================================
      # NEW: Session-based AI consultation with conversation memory
      # ============================================================
      %{
        name: "session_consult",
        description: """
        Query the AI assistant with conversation memory (LocalCode-style).

        Maintains multi-turn conversations with automatic context injection:
        - Your role, responsibilities, and authority limits
        - Recent decisions and messages (last 5 each)
        - Current system status (PostgreSQL, Redis, Ollama)
        - Git context (branch, last commit)
        - Conversation history (last 5 turns)

        Perfect for:
        - Exploratory questions about your role
        - Decision analysis with iterative thinking
        - Strategy planning with follow-up questions
        - Learning from past decisions

        Example workflow:
        1. Ask: "What should I prioritize this quarter?"
        2. Follow-up: "Tell me more about priority #2"
        3. Deep dive: "What are the risks with that approach?"
        """,
        inputSchema: %{
          type: "object",
          properties: %{
            question: %{
              type: "string",
              description: "The question to ask the AI assistant",
              minLength: 1
            },
            session_id: %{
              type: "string",
              description: """
              Session ID to continue an existing conversation.
              Omit this field to start a new session.
              Session IDs look like: "ceo_1699564234_123456"
              """,
            },
            context: %{
              type: "string",
              description: """
              Additional context for this specific query.
              Example: "Budget: $5M, Timeline: Q1 2025, Team size: 50"
              """
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
      # ... your existing tool handlers ...

      # ============================================================
      # NEW: Session consultation handler
      # ============================================================
      "session_consult" ->
        execute_session_consult(args)

      _ ->
        {:error, "Unknown tool: #{tool_name}"}
    end
  end

  # ============================================================
  # NEW: Session-based consultation implementation
  # ============================================================

  defp execute_session_consult(args) do
    alias EchoShared.LLM.DecisionHelper

    # Extract arguments
    question = Map.fetch!(args, "question")
    session_id = Map.get(args, "session_id")  # nil for new session
    context = Map.get(args, "context")

    # Build options
    opts = if context, do: [context: context], else: []

    # Query LLM with session memory
    case DecisionHelper.consult_session(agent_role(), session_id, question, opts) do
      {:ok, result} ->
        # Format successful response
        response = format_session_response(result)
        {:ok, response}

      {:error, :llm_disabled} ->
        {:error, "LLM is disabled for #{agent_role()}. Enable with LLM_ENABLED=true or #{agent_role() |> Atom.to_string() |> String.upcase()}_LLM_ENABLED=true"}

      {:error, :session_not_found} ->
        {:error, "Session not found: #{session_id}. It may have expired after 1 hour of inactivity."}

      {:error, reason} ->
        {:error, "AI consultation failed: #{inspect(reason)}"}
    end
  end

  defp format_session_response(result) do
    # Get model info
    model = EchoShared.LLM.Config.get_model(agent_role())

    # Base response
    base = %{
      response: result.response,
      session_id: result.session_id,
      turn_count: result.turn_count,
      estimated_tokens: result.total_tokens,
      model: model,
      agent: agent_role()
    }

    # Add warnings if context is getting large
    if result.warnings != [] do
      Map.put(base, :warnings, result.warnings)
    else
      base
    end
  end

  # ============================================================
  # IMPORTANT: Set your agent role here!
  # ============================================================
  defp agent_role do
    # Change this to match your agent:
    :ceo                     # CEO agent
    # :cto                   # CTO agent
    # :chro                  # CHRO agent
    # :operations_head       # Operations Head agent
    # :product_manager       # Product Manager agent
    # :senior_architect      # Senior Architect agent
    # :uiux_engineer         # UI/UX Engineer agent
    # :senior_developer      # Senior Developer agent
    # :test_lead             # Test Lead agent
  end

  # ... rest of your agent code ...
end

# ============================================================
# USAGE EXAMPLES
# ============================================================

# Example 1: Start new session
# {
#   "tool": "session_consult",
#   "arguments": {
#     "question": "What are my top priorities as CEO?"
#   }
# }
#
# Response:
# {
#   "response": "As CEO, your top priorities should be:\n1. Strategic planning...",
#   "session_id": "ceo_1699564234_123456",
#   "turn_count": 1,
#   "estimated_tokens": 1876,
#   "model": "llama3.1:8b",
#   "agent": "ceo"
# }

# Example 2: Continue conversation
# {
#   "tool": "session_consult",
#   "arguments": {
#     "session_id": "ceo_1699564234_123456",
#     "question": "Tell me more about priority #2"
#   }
# }
#
# Response:
# {
#   "response": "Regarding strategic planning, you should focus on...",
#   "session_id": "ceo_1699564234_123456",
#   "turn_count": 2,
#   "estimated_tokens": 2341,
#   "model": "llama3.1:8b",
#   "agent": "ceo"
# }

# Example 3: With additional context
# {
#   "tool": "session_consult",
#   "arguments": {
#     "question": "Should we approve this budget request?",
#     "context": "Budget: $2.5M for datacenter. Cash reserves: $10M."
#   }
# }

# Example 4: Context warning (after 8-10 turns)
# {
#   "response": "Based on our discussion...",
#   "session_id": "ceo_1699564234_123456",
#   "turn_count": 9,
#   "estimated_tokens": 4523,
#   "model": "llama3.1:8b",
#   "agent": "ceo",
#   "warnings": [
#     "Session has 9 turns. Consider ending session soon.",
#     "Context size large (4523 tokens). Session approaching limit."
#   ]
# }

# ============================================================
# TESTING
# ============================================================

# Test in IEx:
# iex -S mix
# iex> alias EchoShared.LLM.DecisionHelper
# iex> {:ok, r1} = DecisionHelper.consult_session(:ceo, nil, "What's my role?")
# iex> IO.puts(r1.response)
# iex> {:ok, r2} = DecisionHelper.consult_session(:ceo, r1.session_id, "What are my priorities?")
# iex> IO.puts(r2.response)

# ============================================================
# CONFIGURATION
# ============================================================

# Models configured in apps/echo_shared/config/dev.exs:
# config :echo_shared, :agent_models, %{
#   ceo: "llama3.1:8b",
#   cto: "deepseek-coder:6.7b",
#   chro: "llama3.1:8b",
#   operations_head: "mistral:7b",
#   product_manager: "llama3.1:8b",
#   senior_architect: "deepseek-coder:6.7b",
#   uiux_engineer: "llama3.1:8b",
#   senior_developer: "deepseek-coder:6.7b",
#   test_lead: "deepseek-coder:6.7b"
# }

# Override via environment:
# export CEO_MODEL=qwen2.5:14b
# export CEO_LLM_ENABLED=false
