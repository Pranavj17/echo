defmodule Ceo do
  @moduledoc """
  CEO (Chief Executive Officer) MCP Server.

  The CEO is the highest authority in the ECHO organizational model, responsible for:
  - Strategic planning and company direction
  - Budget allocation across departments
  - C-suite hiring and performance management
  - Crisis management and escalation resolution
  - Final approval on major organizational decisions

  ## Decision Authority

  The CEO has autonomous authority over:
  - Strategic initiatives below confidence threshold
  - Budget allocations up to configured limit
  - Organizational restructuring
  - Crisis response

  ## MCP Tools

  The CEO provides the following tools to Claude Desktop:
  1. approve_strategic_initiative - Review and approve strategic proposals
  2. allocate_budget - Allocate budget to departments or projects
  3. escalate_to_human - Escalate decisions requiring human judgment
  4. review_organizational_health - Get status of all agents and systems
  5. initiate_decision - Start a new organizational decision process
  6. override_decision - Override a decision made by subordinate agents
  """

  use EchoShared.MCP.Server
  require Logger
  import Ecto.Query

  alias EchoShared.MessageBus
  alias EchoShared.Schemas.Decision
  alias EchoShared.Repo
  alias EchoShared.LLM.DecisionHelper

  @impl true
  def agent_info do
    %{
      name: "ceo",
      version: "0.1.0",
      role: :ceo,
      description: "Chief Executive Officer - Strategic leadership and organizational oversight"
    }
  end

  @impl true
  def tools do
    [
      %{
        name: "approve_strategic_initiative",
        description: "Review and approve a strategic initiative proposed by other agents",
        inputSchema: %{
          type: "object",
          properties: %{
            initiative_id: %{
              type: "string",
              description: "The ID of the decision/initiative to approve"
            },
            rationale: %{
              type: "string",
              description: "CEO's rationale for the approval decision"
            },
            budget_allocated: %{
              type: "number",
              description: "Budget allocated in dollars (optional)"
            },
            conditions: %{
              type: "array",
              items: %{type: "string"},
              description: "Any conditions or requirements for the approval (optional)"
            }
          },
          required: ["initiative_id", "rationale"]
        }
      },
      %{
        name: "allocate_budget",
        description: "Allocate budget to a department or project",
        inputSchema: %{
          type: "object",
          properties: %{
            recipient_role: %{
              type: "string",
              description: "The role receiving the budget (e.g., 'cto', 'product_manager')"
            },
            amount: %{
              type: "number",
              description: "Budget amount in dollars"
            },
            purpose: %{
              type: "string",
              description: "Purpose of the budget allocation"
            },
            duration: %{
              type: "string",
              description: "Duration of budget (e.g., 'Q1 2025', 'Annual', 'One-time')"
            }
          },
          required: ["recipient_role", "amount", "purpose"]
        }
      },
      %{
        name: "escalate_to_human",
        description: "Escalate a decision to human judgment when AI confidence is low",
        inputSchema: %{
          type: "object",
          properties: %{
            decision_id: %{
              type: "string",
              description: "The decision ID requiring human input"
            },
            reason: %{
              type: "string",
              description: "Why this decision requires human judgment"
            },
            urgency: %{
              type: "string",
              enum: ["low", "medium", "high", "critical"],
              description: "Urgency level for human response"
            },
            context: %{
              type: "object",
              description: "Additional context for the human decision-maker"
            }
          },
          required: ["decision_id", "reason", "urgency"]
        }
      },
      %{
        name: "review_organizational_health",
        description: "Get comprehensive status of all agents, systems, and organizational metrics",
        inputSchema: %{
          type: "object",
          properties: %{
            include_metrics: %{
              type: "boolean",
              description: "Include detailed performance metrics (default: true)"
            },
            time_range: %{
              type: "string",
              description: "Time range for metrics (e.g., '24h', '7d', '30d', default: '24h')"
            }
          }
        }
      },
      %{
        name: "initiate_decision",
        description: "Start a new organizational decision process (collaborative or hierarchical)",
        inputSchema: %{
          type: "object",
          properties: %{
            decision_type: %{
              type: "string",
              description: "Type of decision (e.g., 'strategic_planning', 'budget', 'hiring')"
            },
            mode: %{
              type: "string",
              enum: ["autonomous", "collaborative", "hierarchical", "human"],
              description: "Decision-making mode"
            },
            participants: %{
              type: "array",
              items: %{type: "string"},
              description: "Roles to include in the decision (for collaborative mode)"
            },
            context: %{
              type: "object",
              description: "Context and details for the decision"
            },
            deadline: %{
              type: "string",
              description: "ISO 8601 deadline for decision (optional)"
            }
          },
          required: ["decision_type", "mode", "context"]
        }
      },
      %{
        name: "override_decision",
        description: "Override a decision made by a subordinate agent (use sparingly)",
        inputSchema: %{
          type: "object",
          properties: %{
            decision_id: %{
              type: "string",
              description: "The decision ID to override"
            },
            override_rationale: %{
              type: "string",
              description: "Detailed rationale for overriding the decision"
            },
            new_outcome: %{
              type: "object",
              description: "The new decision outcome"
            },
            notify_agents: %{
              type: "array",
              items: %{type: "string"},
              description: "Roles to notify of the override"
            }
          },
          required: ["decision_id", "override_rationale", "new_outcome"]
        }
      },
      %{
        name: "ai_consult",
        description: "Consult the CEO's AI advisor for strategic insights and analysis",
        inputSchema: %{
          type: "object",
          properties: %{
            query_type: %{
              type: "string",
              enum: ["decision_analysis", "strategic_question", "option_evaluation", "rationale_generation"],
              description: "Type of AI consultation"
            },
            question: %{
              type: "string",
              description: "The question or decision to analyze"
            },
            context: %{
              type: "object",
              description: "Additional context (options, constraints, data, etc.)"
            }
          },
          required: ["query_type", "question"]
        }
      },
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
      }
    ]
  end

  @impl true
  def execute_tool("approve_strategic_initiative", args) do
    with {:ok, initiative_id} <- validate_required_string(args, "initiative_id"),
         {:ok, rationale} <- validate_required_string(args, "rationale"),
         {:ok, decision} <- load_decision(initiative_id),
         {:ok, approved_decision} <- approve_decision(decision, rationale, args) do
      # Notify relevant agents
      notify_approval(approved_decision)

      result = """
      Strategic Initiative Approved

      Initiative: #{initiative_id}
      Status: Approved by CEO
      Rationale: #{rationale}
      Budget Allocated: $#{format_budget(args["budget_allocated"])}
      Conditions: #{format_conditions(args["conditions"])}

      The decision has been recorded and all relevant agents have been notified.
      """

      {:ok, result}
    else
      {:error, reason} -> {:error, "Failed to approve initiative: #{inspect(reason)}"}
    end
  end

  def execute_tool("allocate_budget", args) do
    with {:ok, recipient_role} <- validate_required_string(args, "recipient_role"),
         {:ok, amount} <- validate_required_number(args, "amount"),
         {:ok, purpose} <- validate_required_string(args, "purpose"),
         :ok <- validate_budget_authority(amount),
         {:ok, allocation} <- create_budget_allocation(recipient_role, amount, purpose, args) do
      # Send budget notification via message bus
      MessageBus.publish_message(
        :ceo,
        String.to_atom(recipient_role),
        :notification,
        "Budget Allocated: $#{format_number(amount)}",
        allocation
      )

      result = """
      Budget Allocated Successfully

      Recipient: #{recipient_role}
      Amount: $#{format_number(amount)}
      Purpose: #{purpose}
      Duration: #{args["duration"] || "Not specified"}

      The budget has been allocated and #{recipient_role} has been notified.
      """

      {:ok, result}
    else
      {:error, :budget_limit_exceeded} ->
        {:error, "Budget amount exceeds CEO autonomous authority limit. Requires board approval."}

      {:error, reason} ->
        {:error, "Failed to allocate budget: #{inspect(reason)}"}
    end
  end

  def execute_tool("escalate_to_human", args) do
    with {:ok, decision_id} <- validate_required_string(args, "decision_id"),
         {:ok, reason} <- validate_required_string(args, "reason"),
         {:ok, urgency} <- validate_required_string(args, "urgency"),
         {:ok, decision} <- load_decision(decision_id),
         {:ok, escalated} <- escalate_decision(decision, reason, urgency, args) do
      # Broadcast escalation notification
      MessageBus.broadcast_message(
        :ceo,
        :escalation,
        "Human Judgment Required: #{decision_id}",
        escalated
      )

      result = """
      Decision Escalated to Human

      Decision ID: #{decision_id}
      Urgency: #{urgency}
      Reason: #{reason}

      The decision has been flagged for human review. All agents have been notified.
      Next steps: Await human decision-maker input.
      """

      {:ok, result}
    else
      {:error, reason} -> {:error, "Failed to escalate decision: #{inspect(reason)}"}
    end
  end

  def execute_tool("review_organizational_health", args) do
    include_metrics = Map.get(args, "include_metrics", true)
    time_range = Map.get(args, "time_range", "24h")

    with {:ok, agent_status} <- get_all_agent_status(),
         {:ok, recent_decisions} <- get_recent_decisions(time_range),
         {:ok, metrics} <- get_organizational_metrics(time_range, include_metrics) do
      result = format_health_report(agent_status, recent_decisions, metrics, include_metrics)
      {:ok, result}
    else
      {:error, reason} -> {:error, "Failed to generate health report: #{inspect(reason)}"}
    end
  end

  def execute_tool("initiate_decision", args) do
    with {:ok, decision_type} <- validate_required_string(args, "decision_type"),
         {:ok, mode} <- validate_required_string(args, "mode"),
         {:ok, context} <- validate_required(args, "context"),
         {:ok, decision} <- create_decision(decision_type, mode, context, args) do
      # Publish decision event
      MessageBus.publish_decision_event(:new, %{
        decision_id: decision.id,
        type: decision_type,
        mode: mode,
        initiator: "ceo"
      })

      # Notify participants
      if mode in ["collaborative", "hierarchical"] do
        notify_participants(decision, args["participants"] || [])
      end

      result = """
      Decision Initiated

      Decision ID: #{decision.id}
      Type: #{decision_type}
      Mode: #{mode}
      Participants: #{format_list(args["participants"])}
      Deadline: #{args["deadline"] || "Not specified"}

      The decision process has been initiated. Participants have been notified.
      """

      {:ok, result}
    else
      {:error, reason} -> {:error, "Failed to initiate decision: #{inspect(reason)}"}
    end
  end

  def execute_tool("override_decision", args) do
    with {:ok, decision_id} <- validate_required_string(args, "decision_id"),
         {:ok, override_rationale} <- validate_required_string(args, "override_rationale"),
         {:ok, new_outcome} <- validate_required(args, "new_outcome"),
         {:ok, decision} <- load_decision(decision_id),
         {:ok, overridden} <- override_decision_record(decision, override_rationale, new_outcome) do
      # Notify affected agents
      agents_to_notify = args["notify_agents"] || []
      notify_override(overridden, agents_to_notify)

      result = """
      Decision Overridden by CEO

      Decision ID: #{decision_id}
      Original Outcome: #{inspect(decision.outcome)}
      New Outcome: #{inspect(new_outcome)}
      Rationale: #{override_rationale}

      The decision has been overridden and all affected agents have been notified.
      """

      {:ok, result}
    else
      {:error, reason} -> {:error, "Failed to override decision: #{inspect(reason)}"}
    end
  end

  def execute_tool("ai_consult", args) do
    with {:ok, query_type} <- validate_required_string(args, "query_type"),
         {:ok, question} <- validate_required_string(args, "question") do

      context = args["context"] || %{}

      result = case query_type do
        "decision_analysis" ->
          decision_context = Map.merge(context, %{
            decision_type: context["decision_type"] || "strategic",
            context: question
          })
          consult_llm_for_decision(decision_context)

        "option_evaluation" ->
          evaluation_context = %{
            question: question,
            options: context["options"] || [],
            criteria: context["criteria"]
          }
          consult_llm_for_evaluation(evaluation_context)

        "rationale_generation" ->
          decision_details = %{
            decision: question,
            factors: context["factors"] || [],
            outcome: context["outcome"]
          }
          consult_llm_for_rationale(decision_details)

        "strategic_question" ->
          consult_llm_simple(question, context["additional_context"])

        _ ->
          {:error, "Unknown query type: #{query_type}"}
      end

      case result do
        {:ok, response} ->
          {:ok, """
          AI Consultation Result (Query Type: #{query_type})

          #{response}

          ---
          Note: This is AI-generated advice. Use your judgment and validate with organizational context.
          """}

        {:error, :llm_disabled} ->
          {:ok, "AI consultation is currently disabled for CEO role. Enable with CEO_LLM_ENABLED=true"}

        {:error, reason} ->
          {:error, "AI consultation failed: #{inspect(reason)}"}
      end
    else
      {:error, reason} -> {:error, "Invalid ai_consult request: #{inspect(reason)}"}
    end
  end

  def execute_tool("session_consult", args) do
    question = Map.fetch!(args, "question")
    session_id = Map.get(args, "session_id")
    context = Map.get(args, "context")

    opts = if context, do: [context: context], else: []

    case DecisionHelper.consult_session(:ceo, session_id, question, opts) do
      {:ok, result} ->
        response = format_session_response(result)
        {:ok, response}

      {:error, :llm_disabled} ->
        {:error, "LLM is disabled for CEO. Enable with LLM_ENABLED=true or CEO_LLM_ENABLED=true"}

      {:error, :session_not_found} ->
        {:error, "Session not found: #{session_id}. It may have expired after 1 hour of inactivity."}

      {:error, reason} ->
        {:error, "AI consultation failed: #{inspect(reason)}"}
    end
  end

  def execute_tool(name, _args) do
    {:error, "Unknown tool: #{name}"}
  end

  ## Private Functions

  defp load_decision(decision_id) do
    case Repo.get(Decision, decision_id) do
      nil -> {:error, :decision_not_found}
      decision -> {:ok, decision}
    end
  end

  defp approve_decision(decision, rationale, args) do
    attrs = %{
      status: :approved,
      outcome: %{
        approved_by: "ceo",
        rationale: rationale,
        budget_allocated: args["budget_allocated"],
        conditions: args["conditions"] || [],
        approved_at: DateTime.utc_now()
      },
      completed_at: DateTime.utc_now()
    }

    decision
    |> Decision.changeset(attrs)
    |> Repo.update()
  end

  defp validate_budget_authority(amount) do
    limit = Application.get_env(:ceo, :autonomous_budget_limit, 1_000_000)

    if amount <= limit do
      :ok
    else
      {:error, :budget_limit_exceeded}
    end
  end

  defp create_budget_allocation(recipient_role, amount, purpose, args) do
    allocation = %{
      recipient_role: recipient_role,
      amount: amount,
      purpose: purpose,
      duration: args["duration"],
      allocated_by: "ceo",
      allocated_at: DateTime.utc_now()
    }

    {:ok, allocation}
  end

  defp escalate_decision(decision, reason, urgency, args) do
    attrs = %{
      status: :escalated,
      outcome: %{
        escalated_by: "ceo",
        reason: reason,
        urgency: urgency,
        context: args["context"],
        escalated_at: DateTime.utc_now()
      }
    }

    decision
    |> Decision.changeset(attrs)
    |> Repo.update()
  end

  defp get_all_agent_status do
    # Query agent_status table for all agents
    query =
      from a in EchoShared.Schemas.AgentStatus,
        select: a,
        order_by: [asc: a.role]

    {:ok, Repo.all(query)}
  end

  defp get_recent_decisions(time_range) do
    hours = parse_time_range(time_range)
    cutoff = DateTime.utc_now() |> DateTime.add(-hours * 3600, :second)

    query =
      from d in Decision,
        where: d.inserted_at >= ^cutoff,
        order_by: [desc: d.inserted_at],
        limit: 20

    {:ok, Repo.all(query)}
  end

  defp get_organizational_metrics(_time_range, false), do: {:ok, %{}}

  defp get_organizational_metrics(time_range, true) do
    hours = parse_time_range(time_range)
    cutoff = DateTime.utc_now() |> DateTime.add(-hours * 3600, :second)

    # Calculate metrics from decisions and messages
    decision_count =
      Repo.one(
        from d in Decision,
          where: d.inserted_at >= ^cutoff,
          select: count(d.id)
      )

    completed_decisions =
      Repo.one(
        from d in Decision,
          where: d.inserted_at >= ^cutoff and d.status in [:approved, :completed],
          select: count(d.id)
      )

    avg_decision_time =
      Repo.one(
        from d in Decision,
          where: d.inserted_at >= ^cutoff and not is_nil(d.completed_at),
          select: avg(fragment("EXTRACT(EPOCH FROM (? - ?))", d.completed_at, d.inserted_at))
      )

    metrics = %{
      decision_count: decision_count || 0,
      completed_decisions: completed_decisions || 0,
      completion_rate:
        if(decision_count > 0, do: Float.round(completed_decisions / decision_count * 100, 1), else: 0),
      avg_decision_time_hours: if(avg_decision_time, do: Float.round(avg_decision_time / 3600, 1), else: 0)
    }

    {:ok, metrics}
  end

  defp format_health_report(agent_status, recent_decisions, metrics, include_metrics) do
    agent_summary =
      Enum.map(agent_status, fn agent ->
        "  - #{agent.role}: #{agent.status} (Last heartbeat: #{format_datetime(agent.last_heartbeat)})"
      end)
      |> Enum.join("\n")

    decision_summary =
      recent_decisions
      |> Enum.take(5)
      |> Enum.map(fn d ->
        "  - #{d.decision_type} (#{d.status}) by #{d.initiator_role} - #{format_datetime(d.inserted_at)}"
      end)
      |> Enum.join("\n")

    metrics_section =
      if include_metrics do
        """

        Organizational Metrics:
          - Total decisions: #{metrics.decision_count}
          - Completed: #{metrics.completed_decisions} (#{metrics.completion_rate}%)
          - Avg decision time: #{metrics.avg_decision_time_hours}h
        """
      else
        ""
      end

    """
    Organizational Health Report

    Agent Status:
    #{agent_summary}

    Recent Decisions (last 5):
    #{decision_summary}
    #{metrics_section}

    Overall Status: #{calculate_overall_health(agent_status, metrics)}
    """
  end

  defp calculate_overall_health(agent_status, metrics) do
    running_agents = Enum.count(agent_status, &(&1.status == :running))
    total_agents = Enum.count(agent_status)

    cond do
      running_agents == total_agents and metrics[:completion_rate] >= 80 -> "Healthy"
      running_agents >= total_agents * 0.8 -> "Good"
      running_agents >= total_agents * 0.5 -> "Degraded"
      true -> "Critical"
    end
  end

  defp create_decision(decision_type, mode, context, args) do
    attrs = %{
      decision_type: decision_type,
      mode: String.to_atom(mode),
      initiator_role: "ceo",
      participants: args["participants"] || [],
      context: context,
      status: :pending,
      metadata: %{
        deadline: args["deadline"],
        initiated_at: DateTime.utc_now()
      }
    }

    %Decision{}
    |> Decision.changeset(attrs)
    |> Repo.insert()
  end

  defp notify_participants(decision, participants) do
    Enum.each(participants, fn participant ->
      MessageBus.publish_message(
        :ceo,
        String.to_atom(participant),
        :request,
        "Decision Participation Required: #{decision.decision_type}",
        %{
          decision_id: decision.id,
          type: decision.decision_type,
          context: decision.context
        }
      )
    end)
  end

  defp override_decision_record(decision, rationale, new_outcome) do
    attrs = %{
      outcome: new_outcome,
      metadata:
        Map.merge(decision.metadata || %{}, %{
          overridden_by: "ceo",
          override_rationale: rationale,
          original_outcome: decision.outcome,
          overridden_at: DateTime.utc_now()
        })
    }

    decision
    |> Decision.changeset(attrs)
    |> Repo.update()
  end

  defp notify_approval(decision) do
    if decision.participants && length(decision.participants) > 0 do
      Enum.each(decision.participants, fn participant ->
        MessageBus.publish_message(
          :ceo,
          String.to_atom(participant),
          :notification,
          "Decision Approved: #{decision.decision_type}",
          %{decision_id: decision.id, outcome: decision.outcome}
        )
      end)
    end

    MessageBus.publish_decision_event(:completed, %{
      decision_id: decision.id,
      status: decision.status
    })
  end

  defp notify_override(decision, agents_to_notify) do
    Enum.each(agents_to_notify, fn agent ->
      MessageBus.publish_message(
        :ceo,
        String.to_atom(agent),
        :notification,
        "Decision Overridden by CEO: #{decision.decision_type}",
        %{
          decision_id: decision.id,
          new_outcome: decision.outcome,
          rationale: decision.metadata["override_rationale"]
        }
      )
    end)
  end

  defp parse_time_range("24h"), do: 24
  defp parse_time_range("7d"), do: 24 * 7
  defp parse_time_range("30d"), do: 24 * 30
  defp parse_time_range(_), do: 24

  defp format_budget(nil), do: "Not allocated"
  defp format_budget(amount), do: format_number(amount)

  defp format_conditions(nil), do: "None"
  defp format_conditions([]), do: "None"
  defp format_conditions(conditions), do: Enum.join(conditions, "; ")

  defp format_list(nil), do: "None"
  defp format_list([]), do: "None"
  defp format_list(list), do: Enum.join(list, ", ")

  defp format_number(num) when is_number(num) do
    num
    |> :erlang.float_to_binary(decimals: 0)
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  end

  defp validate_required_number(args, key) do
    case Map.get(args, key) do
      nil -> {:error, "Missing required field: #{key}"}
      value when is_number(value) -> {:ok, value}
      _ -> {:error, "Field #{key} must be a number"}
    end
  end

  defp validate_required(args, key) do
    case Map.get(args, key) do
      nil -> {:error, "Missing required field: #{key}"}
      value -> {:ok, value}
    end
  end

  defp validate_required_string(args, key) do
    case Map.get(args, key) do
      nil -> {:error, "Missing required field: #{key}"}
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, "Field #{key} must be a string"}
    end
  end

  ## LLM Consultation Helpers

  defp consult_llm_for_decision(decision_context) do
    DecisionHelper.analyze_decision(:ceo, decision_context)
  end

  defp consult_llm_for_evaluation(evaluation_context) do
    DecisionHelper.evaluate_options(:ceo, evaluation_context)
  end

  defp consult_llm_for_rationale(decision_details) do
    DecisionHelper.generate_rationale(:ceo, decision_details)
  end

  defp consult_llm_simple(question, context) do
    DecisionHelper.consult(:ceo, question, context)
  end

  defp format_session_response(result) do
    model = EchoShared.LLM.Config.get_model(:ceo)

    base = %{
      "response" => result.response,
      "session_id" => result.session_id,
      "turn_count" => result.turn_count,
      "estimated_tokens" => result.total_tokens,
      "model" => model,
      "agent" => "ceo"
    }

    if result.warnings != [] do
      Map.put(base, "warnings", result.warnings)
    else
      base
    end
  end
end
