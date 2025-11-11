#!/bin/bash
# Script to add session_consult tool to all ECHO agents

set -euo pipefail

# Agents to update (module name, role atom)
declare -A AGENTS
AGENTS["cto"]="cto"
AGENTS["chro"]="chro"
AGENTS["operations_head"]="operations_head"
AGENTS["product_manager"]="product_manager"
AGENTS["senior_architect"]="senior_architect"
AGENTS["uiux_engineer"]="uiux_engineer"
AGENTS["senior_developer"]="senior_developer"
AGENTS["test_lead"]="test_lead"

# Tool definition template
TOOL_DEF='      },
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

        Perfect for exploratory questions, decision analysis with iterative thinking,
        and strategy planning with follow-up questions.
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
              description: "Session ID to continue conversation (optional, omit for new session)"
            },
            context: %{
              type: "string",
              description: "Additional context for this specific query (optional)"
            }
          },
          required: ["question"]
        }
      }'

# Execute tool handler template (will be customized per agent)
EXECUTE_HANDLER_TEMPLATE='
  def execute_tool("session_consult", args) do
    question = Map.fetch!(args, "question")
    session_id = Map.get(args, "session_id")
    context = Map.get(args, "context")

    opts = if context, do: [context: context], else: []

    case DecisionHelper.consult_session(AGENT_ROLE, session_id, question, opts) do
      {:ok, result} ->
        response = format_session_response(result)
        {:ok, response}

      {:error, :llm_disabled} ->
        {:error, "LLM is disabled for AGENT_NAME. Enable with LLM_ENABLED=true or AGENT_NAME_LLM_ENABLED=true"}

      {:error, :session_not_found} ->
        {:error, "Session not found: #{session_id}. It may have expired after 1 hour of inactivity."}

      {:error, reason} ->
        {:error, "AI consultation failed: #{inspect(reason)}"}
    end
  end
'

# Format session response helper template (will be customized per agent)
FORMAT_HELPER_TEMPLATE='
  defp format_session_response(result) do
    model = EchoShared.LLM.Config.get_model(AGENT_ROLE)

    base = %{
      "response" => result.response,
      "session_id" => result.session_id,
      "turn_count" => result.turn_count,
      "estimated_tokens" => result.total_tokens,
      "model" => model,
      "agent" => "AGENT_NAME"
    }

    if result.warnings != [] do
      Map.put(base, "warnings", result.warnings)
    else
      base
    end
  end'

echo "========================================="
echo " Adding session_consult to all agents"
echo "========================================="
echo

for agent_dir in "${!AGENTS[@]}"; do
  role="${AGENTS[$agent_dir]}"
  file_path="apps/${agent_dir}/lib/${agent_dir}.ex"

  if [ ! -f "$file_path" ]; then
    echo "⚠️  Skipping $agent_dir: File not found at $file_path"
    continue
  fi

  echo "📝 Processing $agent_dir (role: $role)..."

  # Check if already has session_consult
  if grep -q '"session_consult"' "$file_path"; then
    echo "   ✓ Already has session_consult, skipping..."
    continue
  fi

  # Create backup
  cp "$file_path" "${file_path}.backup"

  # Add tool definition (find last tool in list, add before closing ])
  # This is fragile - find the line with last tool's closing }, before ]
  # Look for the pattern: "      }\n    ]\n  end" and insert before ]

  # Create temporary files
  TOOL_TMP=$(mktemp)
  HANDLER_TMP=$(mktemp)
  FORMAT_TMP=$(mktemp)

  # Customize templates with agent-specific values
  echo "$TOOL_DEF" > "$TOOL_TMP"
  echo "$EXECUTE_HANDLER_TEMPLATE" | sed "s/AGENT_ROLE/:$role/g" | sed "s/AGENT_NAME/$agent_dir/g" > "$HANDLER_TMP"
  echo "$FORMAT_HELPER_TEMPLATE" | sed "s/AGENT_ROLE/:$role/g" | sed "s/AGENT_NAME/$agent_dir/g" > "$FORMAT_TMP"

  # Use awk to insert in the right places
  awk -v tool="$(<$TOOL_TMP)" -v handler="$(<$HANDLER_TMP)" -v helper="$(<$FORMAT_TMP)" '
    # State machine
    /^    \]$/  && !tool_added && in_tools {
      print tool
      print $0
      tool_added = 1
      in_tools = 0
      next
    }
    /def tools do/ {
      in_tools = 1
    }
    /def execute_tool\(name, _args\) do/ && !handler_added {
      print handler
      handler_added = 1
    }
    /^end$/ && !helper_added {
      print helper
      helper_added = 1
    }
    { print }
  ' "$file_path" > "${file_path}.tmp"

  mv "${file_path}.tmp" "$file_path"

  # Cleanup
  rm -f "$TOOL_TMP" "$HANDLER_TMP" "$FORMAT_TMP"

  # Compile to check for errors
  echo "   🔨 Compiling..."
  if (cd "apps/$agent_dir" && mix compile 2>&1 | grep -q "Generated"); then
    echo "   ✅ $agent_dir: Success!"
    rm "${file_path}.backup"
  else
    echo "   ❌ $agent_dir: Compilation failed!"
    echo "   Restoring backup..."
    mv "${file_path}.backup" "$file_path"
  fi

  echo
done

echo "========================================="
echo " Summary"
echo "========================================="
echo "✅ Updated all agents with session_consult tool"
echo "Run './rebuild_all.sh' to rebuild all executables"
