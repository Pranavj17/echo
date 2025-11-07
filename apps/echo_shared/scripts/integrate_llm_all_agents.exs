#!/usr/bin/env elixir

# Script to integrate LLM into all remaining ECHO agents
# Usage: elixir integrate_llm_all_agents.exs

defmodule LLMIntegrator do
  @agents [
    {"chro", :chro},
    {"operations_head", :operations_head},
    {"product_manager", :product_manager},
    {"senior_architect", :senior_architect},
    {"uiux_engineer", :uiux_engineer},
    {"senior_developer", :senior_developer},
    {"test_lead", :test_lead}
  ]

  def run do
    IO.puts("🚀 Starting LLM integration for remaining agents...\n")

    Enum.each(@agents, fn {agent_name, agent_role} ->
      integrate_agent(agent_name, agent_role)
    end)

    IO.puts("\n✅ All agents updated successfully!")
  end

  defp integrate_agent(agent_name, agent_role) do
    agent_file = "../../agents/#{agent_name}/lib/#{agent_name}.ex"

    if !File.exists?(agent_file) do
      IO.puts("⚠️  Skipping #{agent_name}: file not found")
    else

    IO.puts("📝 Processing #{agent_name}...")

    # Backup
    File.copy!(agent_file, "#{agent_file}.backup")

    content = File.read!(agent_file)

    # Step 1: Add DecisionHelper alias
    content = add_decision_helper_alias(content)

    # Step 2: Add ai_consult tool
    content = add_ai_consult_tool(content)

    # Step 3: Add execute_tool implementation
    content = add_ai_consult_implementation(content, agent_role)

    # Step 4: Add helper functions
    content = add_llm_helpers(content, agent_role)

    File.write!(agent_file, content)
    IO.puts("   ✓ #{agent_name} updated\n")
    end
  end

  defp add_decision_helper_alias(content) do
    if String.contains?(content, "alias EchoShared.LLM.DecisionHelper") do
      content
    else
      String.replace(
        content,
        ~r/(alias EchoShared\.Repo\n)/,
        "\\1  alias EchoShared.LLM.DecisionHelper\n"
      )
    end
  end

  defp add_ai_consult_tool(content) do
    if String.contains?(content, ~s("ai_consult")) do
      content
    else
      # Add before the closing of tools list
      tool_def = ~s(,
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
      })

      String.replace(
        content,
        ~r/(\}\n      \}\n    \]\n  end\n\n  @impl true\n  def execute_tool)/,
        tool_def <> "\n    ]\n  end\n\n  @impl true\n  def execute_tool"
      )
    end
  end

  defp add_ai_consult_implementation(content, agent_role) do
    if String.contains?(content, ~s(def execute_tool("ai_consult")) do
      content
    else
      impl = """

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
          {:error, "Unknown query type: \#{query_type}"}
      end

      case result do
        {:ok, response} ->
          {:ok, "AI Consultation Result:\\n\\n" <> response}
        {:error, :llm_disabled} ->
          {:ok, "AI consultation disabled. Enable with #{String.upcase(to_string(agent_role))}_LLM_ENABLED=true"}
        {:error, reason} ->
          {:error, "AI consultation failed: \#{inspect(reason)}"}
      end
    end
  end
"""

      String.replace(
        content,
        ~r/\n  def execute_tool\(name, _args\) do\n    \{:error, "Unknown tool: #\{name\}"\}\n  end/,
        impl <> "\n  def execute_tool(name, _args) do\n    {:error, \"Unknown tool: \#{name}\"}\n  end"
      )
    end
  end

  defp add_llm_helpers(content, agent_role) do
    if String.contains?(content, "## LLM Consultation Helpers") do
      content
    else
      helpers = """

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

      String.replace(content, ~r/end\n$/, helpers <> "end\n")
    end
  end
end

LLMIntegrator.run()
