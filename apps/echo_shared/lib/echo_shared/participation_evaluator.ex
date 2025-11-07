defmodule EchoShared.ParticipationEvaluator do
  @moduledoc """
  Evaluates whether an agent should participate in a broadcast task or message.

  Uses a two-phase approach:
  1. Fast-path filtering: Quick keyword/role matching (no LLM)
  2. Deep evaluation: LLM-powered relevance analysis (async)

  This enables agents to self-select for tasks dynamically without
  hardcoded routing logic.
  """

  require Logger
  alias EchoShared.LLM.Client, as: LLMClient
  alias EchoShared.LLM.Config, as: LLMConfig

  @type role :: atom()
  @type confidence :: float()
  @type participation_type :: :lead | :assist | :observe | :none

  @doc """
  Determines if an agent should participate in a task/message.

  Returns:
  - {:yes, confidence, type} - Should participate (lead, assist, or observe)
  - {:no, reason} - Should not participate
  - {:defer, seconds} - Wait before deciding (for complex analysis)

  ## Examples

      iex> should_participate?(:cto, %{"subject" => "Database optimization", "content" => "Need help"})
      {:yes, 0.95, :lead}

      iex> should_participate?(:chro, %{"subject" => "Database optimization", "content" => "Technical work"})
      {:no, "Not HR-related"}
  """
  @spec should_participate?(role(), map(), map()) ::
          {:yes, confidence(), participation_type()} | {:no, String.t()} | {:defer, non_neg_integer()}
  def should_participate?(role, message, context \\ %{}) do
    # Phase 1: Fast-path filtering (synchronous, <10ms)
    case fast_path_filter(role, message) do
      {:definitely_no, reason} ->
        Logger.debug("[#{role}] Fast-path: Not relevant - #{reason}")
        {:no, reason}

      {:definitely_yes, confidence} ->
        Logger.info("[#{role}] Fast-path: Highly relevant (#{confidence})")
        {:yes, confidence, infer_participation_type(role, message)}

      {:maybe, _score} ->
        # Phase 2: LLM evaluation (async, 5-30s)
        Logger.debug("[#{role}] Fast-path: Uncertain, querying LLM")
        evaluate_with_llm_async(role, message, context)
    end
  end

  @doc """
  Fast synchronous filter based on keywords and role matching.
  Returns:
  - {:definitely_no, reason} - Obviously irrelevant
  - {:definitely_yes, confidence} - Obviously relevant
  - {:maybe, score} - Needs LLM evaluation
  """
  def fast_path_filter(role, message) do
    subject = Map.get(message, "subject", "")
    content = Map.get(message, "content", "")

    # Convert content to searchable text (handle maps, lists, strings)
    content_text = extract_text_from_content(content)
    full_text = "#{subject} #{content_text}" |> String.downcase()

    # Role-specific keyword patterns
    keywords = get_role_keywords(role)
    anti_keywords = get_role_anti_keywords(role)

    # Check for anti-patterns (definitely not relevant)
    if Enum.any?(anti_keywords, &String.contains?(full_text, &1)) do
      {:definitely_no, "Contains anti-keywords for #{role}"}
    else
      # Score based on keyword matches
      score = calculate_keyword_score(full_text, keywords)

      cond do
        score >= 0.8 -> {:definitely_yes, score}
        score <= 0.2 -> {:definitely_no, "Low keyword relevance (#{score})"}
        true -> {:maybe, score}
      end
    end
  end

  @doc """
  Asynchronously evaluate relevance using LLM.
  Spawns a linked task and returns quickly with :defer.
  """
  def evaluate_with_llm_async(role, message, context) do
    # Spawn async task for LLM consultation
    parent = self()
    message_id = message["id"] || "unknown_#{:erlang.system_time()}"  # Fix #3: Message ID validation

    # Fix #2: Use spawn_link instead of Task.start to prevent process leaks
    spawn_link(fn ->
      try do
        result = evaluate_with_llm_sync(role, message, context)
        send(parent, {:participation_decision, role, message_id, result})
      catch
        kind, reason ->
          Logger.error("[#{role}] LLM evaluation crashed: #{inspect(kind)} #{inspect(reason)}")
          send(parent, {:participation_decision, role, message_id, {:no, "LLM evaluation failed"}})
      end
    end)

    # Return immediately with defer
    {:defer, 5}
  end

  @doc """
  Synchronous LLM evaluation for testing or when async not needed.
  """
  def evaluate_with_llm_sync(role, message, context) do
    model = LLMConfig.get_model(role)

    prompt = build_participation_prompt(role, message, context)

    messages = [
      %{role: "system", content: get_role_description(role)},
      %{role: "user", content: prompt}
    ]

    case LLMClient.chat(model, messages) do
      {:ok, response} ->
        parse_llm_participation_response(response, role)

      {:error, reason} ->
        Logger.warning("[#{role}] LLM evaluation failed: #{inspect(reason)}, defaulting to NO")
        {:no, "LLM evaluation failed: #{reason}"}
    end
  end

  # Private Functions

  defp get_role_keywords(:ceo) do
    ["strategy", "leadership", "decision", "priority", "direction", "vision", "organization"]
  end

  defp get_role_keywords(:cto) do
    ["technical", "technology", "architecture", "infrastructure", "security", "performance", "scalability"]
  end

  defp get_role_keywords(:chro) do
    ["hiring", "hr", "human resources", "talent", "recruitment", "team member", "employee", "culture"]
  end

  defp get_role_keywords(:operations_head) do
    ["operations", "deployment", "infrastructure", "monitoring", "availability", "reliability", "ops"]
  end

  defp get_role_keywords(:product_manager) do
    ["product", "feature", "requirements", "user story", "roadmap", "customer", "market", "prioritization"]
  end

  defp get_role_keywords(:senior_architect) do
    ["architecture", "design", "system design", "technical design", "component", "integration", "api"]
  end

  defp get_role_keywords(:uiux_engineer) do
    ["ui", "ux", "interface", "design", "user experience", "frontend", "visual", "usability"]
  end

  defp get_role_keywords(:senior_developer) do
    ["development", "implementation", "code", "coding", "programming", "bug", "feature development"]
  end

  defp get_role_keywords(:test_lead) do
    ["testing", "test", "qa", "quality", "bug", "validation", "verification", "coverage"]
  end

  defp get_role_anti_keywords(:cto) do
    ["only hr", "purely hiring", "just recruiting"]
  end

  defp get_role_anti_keywords(:chro) do
    ["technical only", "no people", "purely technical"]
  end

  defp get_role_anti_keywords(_role), do: []

  defp calculate_keyword_score(text, keywords) do
    matches = Enum.count(keywords, &String.contains?(text, &1))
    total = length(keywords)

    if total > 0, do: matches / total, else: 0.0
  end

  # Extract searchable text from content (handles strings, maps, lists)
  defp extract_text_from_content(content) when is_binary(content), do: content

  defp extract_text_from_content(content) when is_map(content) do
    content
    |> Enum.map(fn {k, v} -> "#{k} #{extract_text_from_content(v)}" end)
    |> Enum.join(" ")
  end

  defp extract_text_from_content(content) when is_list(content) do
    content
    |> Enum.map(&extract_text_from_content/1)
    |> Enum.join(" ")
  end

  defp extract_text_from_content(_), do: ""

  defp get_role_description(:ceo) do
    "You are the CEO responsible for strategic leadership, organizational priorities, and high-level decision making."
  end

  defp get_role_description(:cto) do
    "You are the CTO responsible for technical leadership, architecture decisions, and technology strategy."
  end

  defp get_role_description(:chro) do
    "You are the CHRO responsible for human resources, talent management, hiring, and organizational culture."
  end

  defp get_role_description(:operations_head) do
    "You are the Operations Head responsible for infrastructure, deployments, monitoring, and operational reliability."
  end

  defp get_role_description(:product_manager) do
    "You are the Product Manager responsible for product strategy, requirements, feature prioritization, and customer needs."
  end

  defp get_role_description(:senior_architect) do
    "You are the Senior Architect responsible for system design, technical architecture, and component integration."
  end

  defp get_role_description(:uiux_engineer) do
    "You are the UI/UX Engineer responsible for user interface design, user experience, and frontend architecture."
  end

  defp get_role_description(:senior_developer) do
    "You are the Senior Developer responsible for implementation, coding, feature development, and bug fixes."
  end

  defp get_role_description(:test_lead) do
    "You are the Test Lead responsible for quality assurance, testing strategy, test coverage, and validation."
  end

  defp build_participation_prompt(role, message, context) do
    """
    TASK: Evaluate if you should participate in this work.

    MESSAGE:
    Subject: #{message["subject"]}
    From: #{message["from"]}
    Content: #{message["content"]}

    CONTEXT:
    Current workload: #{Map.get(context, :workload, "unknown")}
    Your expertise: #{Map.get(context, :expertise, "general")}

    INSTRUCTIONS:
    Determine if this task is relevant to your role as #{role}.
    Consider:
    1. Does this require my specific expertise?
    2. Am I the right person to lead, assist, or just observe?
    3. Is my participation valuable or redundant?

    Respond in this format:
    DECISION: [YES/NO]
    CONFIDENCE: [0.0-1.0]
    TYPE: [LEAD/ASSIST/OBSERVE]
    REASONING: [Brief explanation]

    Be honest and selective. Say NO if others are better suited.
    """
  end

  defp parse_llm_participation_response(response, role) do
    text = response |> String.downcase()

    decision =
      cond do
        String.contains?(text, "decision: yes") -> :yes
        String.contains?(text, "decision: no") -> :no
        true -> :no
      end

    # Fix #9: Robust confidence parsing (handles integers + floats, clamps values)
    confidence =
      case Regex.run(~r/confidence:\s*([0-9]*\.?[0-9]+)/, text) do
        [_, conf_str] ->
          case Float.parse(conf_str) do
            {conf, _} -> min(max(conf, 0.0), 1.0)  # Clamp to [0.0, 1.0]
            :error -> 0.5
          end
        _ -> 0.5
      end

    participation_type =
      cond do
        String.contains?(text, "type: lead") -> :lead
        String.contains?(text, "type: assist") -> :assist
        String.contains?(text, "type: observe") -> :observe
        true -> :assist
      end

    reasoning =
      case Regex.run(~r/reasoning:\s*(.+)$/m, text) do
        [_, reason] -> String.trim(reason)
        _ -> "LLM evaluation"
      end

    case decision do
      :yes ->
        Logger.info("[#{role}] LLM decided: YES (#{confidence}) as #{participation_type} - #{reasoning}")
        {:yes, confidence, participation_type}

      :no ->
        Logger.debug("[#{role}] LLM decided: NO - #{reasoning}")
        {:no, reasoning}
    end
  end

  defp infer_participation_type(role, message) do
    # Infer based on role and message type
    from = message["from"]

    cond do
      # Leadership roles lead when task comes from CEO
      role in [:cto, :chro, :operations_head] and from == "ceo" -> :lead
      # Technical leads lead technical tasks
      role in [:senior_architect, :test_lead] -> :lead
      # Implementers assist
      role in [:senior_developer, :uiux_engineer] -> :assist
      # Default: assist
      true -> :assist
    end
  end
end
