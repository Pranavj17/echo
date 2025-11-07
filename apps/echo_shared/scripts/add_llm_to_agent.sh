#!/bin/bash

# Script to add LLM integration to an ECHO agent
# Usage: ./add_llm_to_agent.sh <agent_name> <agent_role>
# Example: ./add_llm_to_agent.sh chro chro

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <agent_name> <agent_role>"
    echo "Example: $0 chro chro"
    exit 1
fi

AGENT_NAME=$1
AGENT_ROLE=$2
AGENT_DIR="../agents/${AGENT_NAME}"
AGENT_FILE="${AGENT_DIR}/lib/${AGENT_NAME}.ex"

if [ ! -f "$AGENT_FILE" ]; then
    echo "Error: Agent file not found: $AGENT_FILE"
    exit 1
fi

echo "Adding LLM integration to ${AGENT_NAME} agent..."

# Create backup
cp "$AGENT_FILE" "${AGENT_FILE}.backup"

# The integration will be done manually via Elixir since shell scripting for complex edits is error-prone
# Instead, we'll create an Elixir script to do the modifications

cat > /tmp/add_llm_integration.exs << 'EOF'
[agent_file, agent_role] = System.argv()

content = File.read!(agent_file)

# Step 1: Add DecisionHelper alias after Repo alias
if String.contains?(content, "alias EchoShared.LLM.DecisionHelper") do
  IO.puts("✓ DecisionHelper alias already present")
else
  content = String.replace(
    content,
    ~r/(alias EchoShared\.Repo)/,
    "\\1\n  alias EchoShared.LLM.DecisionHelper"
  )
  IO.puts("✓ Added DecisionHelper alias")
end

# Step 2: Add ai_consult tool before closing the tools list
if String.contains?(content, ~s("ai_consult")) do
  IO.puts("✓ ai_consult tool already present")
else
  # Find the last tool in the array and add ai_consult after it
  ai_consult_tool = """
      },
      %{
        name: "ai_consult",
        description: "Consult AI advisor for insights and analysis",
        inputSchema: %{
          type: "object",
          properties: %{
            query_type: %{
              type: "string",
              enum: ["decision_analysis", "question", "option_evaluation"],
              description: "Type of AI consultation"
            },
            question: %{
              type: "string",
              description: "The question or decision to analyze"
            },
            context: %{
              type: "object",
              description: "Additional context"
            }
          },
          required: ["query_type", "question"]
        }
      }
    ]
  end
  """

  content = String.replace(
    content,
    ~r/\}\n    \]\n  end\n\n  @impl true\n  def execute_tool/,
    ai_consult_tool <> "\n\n  @impl true\n  def execute_tool"
  )
  IO.puts("✓ Added ai_consult tool")
end

# Step 3: Add execute_tool for ai_consult
if String.contains?(content, ~s(def execute_tool("ai_consult")) do
  IO.puts("✓ ai_consult execute_tool already present")
else
  ai_consult_impl = """

  def execute_tool("ai_consult", args) do
    with {:ok, query_type} <- validate_required_string(args, "query_type"),
         {:ok, question} <- validate_required_string(args, "question") do

      context = args["context"] || %{}

      result = case query_type do
        "decision_analysis" ->
          decision_context = Map.merge(context, %{
            decision_type: context["decision_type"] || "general",
            context: question
          })
          DecisionHelper.analyze_decision(:#{agent_role}, decision_context)

        "option_evaluation" ->
          evaluation_context = %{
            question: question,
            options: context["options"] || [],
            criteria: context["criteria"]
          }
          DecisionHelper.evaluate_options(:#{agent_role}, evaluation_context)

        "question" ->
          DecisionHelper.consult(:#{agent_role}, question, context["additional_context"])

        _ ->
          {:error, "Unknown query type: #{query_type}"}
      end

      case result do
        {:ok, response} ->
          {:ok, "AI Consultation Result:\\n\\n" <> response <> "\\n\\n---\\nNote: AI-generated advice."}
        {:error, :llm_disabled} ->
          {:ok, "AI consultation is currently disabled. Enable with #{String.upcase(agent_role)}_LLM_ENABLED=true"}
        {:error, reason} ->
          {:error, "AI consultation failed: #{inspect(reason)}"}
      end
    end
  end
  """

  content = String.replace(
    content,
    ~r/\n  def execute_tool\(name, _args\) do\n    \{:error, "Unknown tool: #\{name\}"\}\n  end/,
    ai_consult_impl <> "\n\n  def execute_tool(name, _args) do\n    {:error, \"Unknown tool: \#{name}\"}\n  end"
  )
  IO.puts("✓ Added ai_consult execute_tool implementation")
end

# Step 4: Add LLM helper functions before final end
if String.contains?(content, "## LLM Consultation Helpers") do
  IO.puts("✓ LLM helper functions already present")
else
  llm_helpers = """

  ## LLM Consultation Helpers

  defp consult_llm_for_decision(decision_context) do
    DecisionHelper.analyze_decision(:#{agent_role}, decision_context)
  end

  defp consult_llm_for_evaluation(evaluation_context) do
    DecisionHelper.evaluate_options(:#{agent_role}, evaluation_context)
  end

  defp consult_llm_simple(question, context) do
    DecisionHelper.consult(:#{agent_role}, question, context)
  end
"""

  content = String.replace(
    content,
    ~r/end\n$/,
    llm_helpers <> "end\n"
  )
  IO.puts("✓ Added LLM helper functions")
end

File.write!(agent_file, content)
IO.puts("✅ Successfully integrated LLM into #{agent_role} agent!")
EOF

# Run the Elixir script
elixir /tmp/add_llm_integration.exs "$AGENT_FILE" "$AGENT_ROLE"

echo "Done! Backup created at ${AGENT_FILE}.backup"
