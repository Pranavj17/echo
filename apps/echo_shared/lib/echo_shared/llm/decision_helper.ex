defmodule EchoShared.LLM.DecisionHelper do
  @moduledoc """
  Helper functions for agents to consult LLMs during decision-making.

  Provides high-level functions that agents can use to get AI assistance
  for analyzing decisions, generating rationales, evaluating options, etc.

  ## Usage

      # Analyze a decision context
      {:ok, analysis} = DecisionHelper.analyze_decision(:ceo, %{
        decision_type: "budget_allocation",
        context: "Q1 2025 budget allocation across departments",
        options: ["Conservative", "Growth-focused", "Balanced"]
      })

      # Generate a rationale
      {:ok, rationale} = DecisionHelper.generate_rationale(:cto, %{
        decision: "Approve microservices architecture",
        factors: ["scalability", "team expertise", "time to market"]
      })
  """

  require Logger
  alias EchoShared.LLM.{Client, Config}

  @doc """
  Analyze a decision and provide AI-powered insights.

  ## Parameters

  - `role` - Agent role (atom)
  - `decision_context` - Map with decision details:
    - `:decision_type` - Type of decision
    - `:context` - Background context
    - `:options` - (optional) List of options to consider
    - `:constraints` - (optional) Constraints or requirements
    - `:data` - (optional) Relevant data points

  ## Returns

  - `{:ok, analysis_text}` - AI analysis and recommendations
  - `{:error, reason}` - If LLM unavailable or disabled
  - `{:error, :llm_disabled}` - If LLM is disabled for this role

  ## Example

      DecisionHelper.analyze_decision(:ceo, %{
        decision_type: "strategic_initiative",
        context: "Expand into European market",
        options: ["Immediate expansion", "Pilot program", "Defer"],
        constraints: ["$5M budget", "12 month timeline"],
        data: %{current_revenue: "$50M", team_size: 100}
      })
  """
  def analyze_decision(role, decision_context) do
    unless Config.llm_enabled?(role) do
      {:error, :llm_disabled}
    else

    model = Config.get_model(role)
    system_prompt = Config.get_system_prompt(role)
    opts = Config.get_generation_opts(role)

    user_prompt = build_decision_prompt(decision_context)

    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_prompt}
    ]

    Logger.info("#{role}: Consulting LLM (#{model}) for decision analysis")

    case Client.chat(model, messages, opts) do
      {:ok, analysis} ->
        {:ok, analysis}

      {:error, reason} ->
        Logger.warning("#{role}: LLM consultation failed: #{inspect(reason)}")
        {:error, reason}
    end
    end
  end

  @doc """
  Generate a rationale for a decision that has been made.

  Useful for explaining decisions to other agents or humans.

  ## Parameters

  - `role` - Agent role
  - `decision_details` - Map with:
    - `:decision` - The decision made
    - `:factors` - Factors that influenced the decision
    - `:outcome` - (optional) Expected outcome

  ## Returns

  - `{:ok, rationale_text}` - Generated rationale
  - `{:error, reason}` - On failure
  """
  def generate_rationale(role, decision_details) do
    unless Config.llm_enabled?(role) do
      {:error, :llm_disabled}
    else
      model = Config.get_model(role)
      system_prompt = Config.get_system_prompt(role)
      opts = Config.get_generation_opts(role, %{max_tokens: 1000})

      user_prompt = """
      Generate a clear, concise rationale for the following decision:

      Decision: #{decision_details[:decision]}
      Key Factors: #{format_list(decision_details[:factors])}
      #{if decision_details[:outcome], do: "Expected Outcome: #{decision_details[:outcome]}", else: ""}

      Provide a professional rationale (2-3 paragraphs) that explains the reasoning behind this decision.
      Focus on the strategic value and risk considerations.
      """

      messages = [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_prompt}
      ]

      Logger.info("#{role}: Generating decision rationale with #{model}")

      Client.chat(model, messages, opts)
    end
  end

  @doc """
  Evaluate and compare multiple options for a decision.

  Returns analysis of pros/cons and a recommendation.

  ## Parameters

  - `role` - Agent role
  - `evaluation_context` - Map with:
    - `:question` - The decision question
    - `:options` - List of option maps with :name and :description
    - `:criteria` - (optional) Evaluation criteria

  ## Returns

  - `{:ok, evaluation_text}` - Comparative analysis
  - `{:error, reason}` - On failure
  """
  def evaluate_options(role, evaluation_context) do
    unless Config.llm_enabled?(role) do
      {:error, :llm_disabled}
    else
      model = Config.get_model(role)
      system_prompt = Config.get_system_prompt(role)
      opts = Config.get_generation_opts(role)

      user_prompt = build_evaluation_prompt(evaluation_context)

      messages = [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_prompt}
      ]

      Logger.info("#{role}: Evaluating options with #{model}")

      Client.chat(model, messages, opts)
    end
  end

  @doc """
  Get a quick AI consultation on a specific question.

  Simpler interface for ad-hoc questions.

  ## Parameters

  - `role` - Agent role
  - `question` - The question to ask
  - `context` - (optional) Additional context

  ## Returns

  - `{:ok, answer_text}` - AI response
  - `{:error, reason}` - On failure
  """
  def consult(role, question, context \\ nil) do
    unless Config.llm_enabled?(role) do
      {:error, :llm_disabled}
    else
      model = Config.get_model(role)
      system_prompt = Config.get_system_prompt(role)
      opts = Config.get_generation_opts(role, %{max_tokens: 1500})

      user_prompt = if context do
        "Context: #{context}\n\nQuestion: #{question}"
      else
        question
      end

      messages = [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_prompt}
      ]

      Logger.info("#{role}: Consulting #{model}")

      Client.chat(model, messages, opts)
    end
  end

  @doc """
  Session-based AI consultation with conversation memory (LocalCode-style).

  Maintains multi-turn conversation with automatic context injection including:
  - Agent role and responsibilities
  - Recent decisions and messages
  - System status
  - Git context
  - Conversation history (last 5 turns)

  ## Parameters

  - `role` - Agent role
  - `session_id` - Existing session ID, or `nil` to start new session
  - `question` - The question to ask
  - `opts` - Options:
    - `:context` - Additional context for this query
    - `:temperature` - Override temperature
    - `:max_tokens` - Override max_tokens

  ## Returns

  - `{:ok, %{response: text, session_id: id, turn_count: n, warnings: []}}` on success
  - `{:error, reason}` - On failure

  ## Example

      # Start new session
      {:ok, result} = DecisionHelper.consult_session(:ceo, nil, "What should I prioritize?")
      # => %{response: "...", session_id: "ceo_1234567_12345", turn_count: 1, warnings: []}

      # Continue conversation
      {:ok, result2} = DecisionHelper.consult_session(:ceo, result.session_id, "Tell me more about that")
      # => %{response: "...", session_id: "ceo_1234567_12345", turn_count: 2, warnings: []}

      # End session when done
      EchoShared.LLM.Session.end_session(result.session_id)
  """
  def consult_session(role, session_id, question, opts \\ []) do
    unless Config.llm_enabled?(role) do
      {:error, :llm_disabled}
    else
      alias EchoShared.LLM.Session

      # Add agent_role to opts if creating new session
      query_opts = if session_id == nil do
        Keyword.put(opts, :agent_role, role)
      else
        opts
      end

      Logger.info("#{role}: Session-based query (session: #{session_id || "new"})")

      Session.query(session_id, question, query_opts)
    end
  end

  @doc """
  Generate code or technical implementation guidance.

  Optimized for technical roles (CTO, Senior Developer, etc.)

  ## Parameters

  - `role` - Agent role
  - `task` - Map with:
    - `:description` - What to implement
    - `:language` - (optional) Programming language
    - `:requirements` - (optional) Specific requirements
    - `:constraints` - (optional) Constraints

  ## Returns

  - `{:ok, implementation_text}` - Generated code/guidance
  - `{:error, reason}` - On failure
  """
  def generate_implementation(role, task) do
    unless Config.llm_enabled?(role) do
      {:error, :llm_disabled}
    else
      model = Config.get_model(role)
      system_prompt = Config.get_system_prompt(role)
      # Lower temperature for code generation
      opts = Config.get_generation_opts(role, %{temperature: 0.2, max_tokens: 3000})

      user_prompt = """
      Generate implementation guidance for the following task:

      Description: #{task[:description]}
      #{if task[:language], do: "Language: #{task[:language]}", else: ""}
      #{if task[:requirements], do: "Requirements:\n#{format_list(task[:requirements])}", else: ""}
      #{if task[:constraints], do: "Constraints:\n#{format_list(task[:constraints])}", else: ""}

      Provide clear, well-documented code examples with explanations.
      Include error handling and best practices.
      """

      messages = [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_prompt}
      ]

      Logger.info("#{role}: Generating implementation with #{model}")

      Client.chat(model, messages, opts)
    end
  end

  ## Private Helper Functions

  defp build_decision_prompt(context) do
    """
    Analyze the following decision and provide your expert insights:

    Decision Type: #{context[:decision_type]}
    Context: #{context[:context]}

    #{if context[:options] do
      "Options:\n" <> (context[:options] |> Enum.with_index(1) |> Enum.map(fn {opt, i} -> "  #{i}. #{opt}" end) |> Enum.join("\n"))
    else
      ""
    end}

    #{if context[:constraints] do
      "Constraints:\n" <> format_list(context[:constraints])
    else
      ""
    end}

    #{if context[:data] do
      "Relevant Data:\n" <> format_map(context[:data])
    else
      ""
    end}

    Please provide:
    1. Your analysis of the situation
    2. Key considerations and risks
    3. Your recommendation with clear reasoning

    Be concise but thorough. Focus on strategic impact and practical implications.
    """
  end

  defp build_evaluation_prompt(context) do
    """
    Evaluate the following options and provide a comparative analysis:

    Question: #{context[:question]}

    Options:
    #{format_options(context[:options])}

    #{if context[:criteria] do
      "Evaluation Criteria:\n" <> format_list(context[:criteria])
    else
      ""
    end}

    For each option, analyze:
    - Pros and cons
    - Risks and opportunities
    - Fit with organizational goals

    Then provide your recommendation with clear reasoning.
    """
  end

  defp format_list(items) when is_list(items) do
    items
    |> Enum.with_index(1)
    |> Enum.map(fn {item, i} -> "  #{i}. #{item}" end)
    |> Enum.join("\n")
  end

  defp format_list(_), do: ""

  defp format_map(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> "  - #{k}: #{v}" end)
    |> Enum.join("\n")
  end

  defp format_map(_), do: ""

  defp format_options(options) when is_list(options) do
    options
    |> Enum.with_index(1)
    |> Enum.map(fn {opt, i} ->
      case opt do
        %{name: name, description: desc} ->
          "#{i}. #{name}\n   #{desc}"
        name when is_binary(name) ->
          "#{i}. #{name}"
        _ ->
          "#{i}. #{inspect(opt)}"
      end
    end)
    |> Enum.join("\n\n")
  end

  defp format_options(_), do: ""
end
