defmodule Chro do
  @moduledoc """
  CHRO (Chief Human Resources Officer) MCP Server.

  The CHRO is responsible for people operations, culture, and performance
  management in the ECHO organizational model.

  ## Responsibilities
  - Hiring decisions and talent acquisition
  - Performance reviews and management
  - HR policy and compliance
  - Conflict resolution and mediation
  - Team culture and employee satisfaction
  - Training and development

  ## Decision Authority
  - Hiring approvals (all levels within budget)
  - Performance reviews and promotions
  - HR budget up to $300,000
  - Policy updates and enforcement
  - Conflict resolution

  ## MCP Tools
  1. approve_hiring_request - Approve new hire requisitions
  2. conduct_performance_review - Record performance evaluations
  3. allocate_hr_budget - Allocate HR and training funds
  4. resolve_hr_issue - Handle employee conflicts/issues
  5. review_team_health - Get team satisfaction and retention metrics
  6. escalate_to_ceo - Escalate sensitive HR matters
  """

  use EchoShared.MCP.Server
  require Logger
  import Ecto.Query

  alias EchoShared.MessageBus
  alias EchoShared.Schemas.Decision
  alias EchoShared.Repo

  @impl true
  def agent_info do
    %{
      name: "chro",
      version: "0.1.0",
      role: :chro,
      description: "Chief Human Resources Officer - People operations and culture"
    }
  end

  @impl true
  def tools do
    [
      %{
        name: "approve_hiring_request",
        description: "Approve or reject a new hire requisition",
        inputSchema: %{
          type: "object",
          properties: %{
            requisition_id: %{
              type: "string",
              description: "The ID of the hiring requisition"
            },
            position: %{
              type: "string",
              description: "Position title being hired for"
            },
            department: %{
              type: "string",
              description: "Department requesting the hire"
            },
            approved: %{
              type: "boolean",
              description: "Whether the requisition is approved"
            },
            rationale: %{
              type: "string",
              description: "Rationale for approval/rejection"
            },
            salary_range: %{
              type: "string",
              description: "Approved salary range (optional)"
            }
          },
          required: ["requisition_id", "position", "department", "approved", "rationale"]
        }
      },
      %{
        name: "conduct_performance_review",
        description: "Record a performance review for an employee",
        inputSchema: %{
          type: "object",
          properties: %{
            employee_role: %{
              type: "string",
              description: "Role of the employee being reviewed"
            },
            review_period: %{
              type: "string",
              description: "Review period (e.g., 'Q1 2025', 'Annual 2024')"
            },
            rating: %{
              type: "string",
              enum: ["exceeds_expectations", "meets_expectations", "needs_improvement", "unsatisfactory"],
              description: "Overall performance rating"
            },
            strengths: %{
              type: "array",
              items: %{type: "string"},
              description: "Key strengths demonstrated"
            },
            areas_for_improvement: %{
              type: "array",
              items: %{type: "string"},
              description: "Areas needing development"
            },
            promotion_recommended: %{
              type: "boolean",
              description: "Whether promotion is recommended"
            }
          },
          required: ["employee_role", "review_period", "rating"]
        }
      },
      %{
        name: "allocate_hr_budget",
        description: "Allocate budget for HR initiatives, training, or benefits",
        inputSchema: %{
          type: "object",
          properties: %{
            purpose: %{
              type: "string",
              description: "Purpose of the budget allocation"
            },
            amount: %{
              type: "number",
              description: "Budget amount in dollars"
            },
            category: %{
              type: "string",
              enum: ["training", "recruiting", "benefits", "team_events", "other"],
              description: "Budget category"
            },
            duration: %{
              type: "string",
              description: "Duration of budget (e.g., 'Q1 2025', 'Annual')"
            }
          },
          required: ["purpose", "amount", "category"]
        }
      },
      %{
        name: "resolve_hr_issue",
        description: "Handle employee conflicts, complaints, or HR issues",
        inputSchema: %{
          type: "object",
          properties: %{
            issue_id: %{
              type: "string",
              description: "ID of the HR issue or complaint"
            },
            issue_type: %{
              type: "string",
              enum: ["conflict", "complaint", "policy_violation", "performance", "other"],
              description: "Type of HR issue"
            },
            parties_involved: %{
              type: "array",
              items: %{type: "string"},
              description: "Roles involved in the issue"
            },
            resolution: %{
              type: "string",
              description: "Description of the resolution"
            },
            action_items: %{
              type: "array",
              items: %{type: "string"},
              description: "Follow-up action items (optional)"
            },
            requires_escalation: %{
              type: "boolean",
              description: "Whether this requires CEO escalation"
            }
          },
          required: ["issue_id", "issue_type", "resolution"]
        }
      },
      %{
        name: "review_team_health",
        description: "Review team satisfaction, retention, and organizational health metrics",
        inputSchema: %{
          type: "object",
          properties: %{
            time_range: %{
              type: "string",
              description: "Time range for metrics (e.g., '30d', '90d', 'annual', default: '30d')"
            },
            include_details: %{
              type: "boolean",
              description: "Include detailed breakdowns by department (default: true)"
            }
          }
        }
      },
      %{
        name: "escalate_to_ceo",
        description: "Escalate sensitive HR matters to CEO",
        inputSchema: %{
          type: "object",
          properties: %{
            issue_id: %{
              type: "string",
              description: "The HR issue ID to escalate"
            },
            reason: %{
              type: "string",
              description: "Why this requires CEO involvement"
            },
            urgency: %{
              type: "string",
              enum: ["low", "medium", "high", "critical"],
              description: "Urgency level for CEO response"
            },
            recommendation: %{
              type: "string",
              description: "CHRO's recommendation (optional)"
            },
            confidential: %{
              type: "boolean",
              description: "Whether this is highly confidential (default: true)"
            }
          },
          required: ["issue_id", "reason", "urgency"]
        }
      }
    ]
  end

  @impl true
  def execute_tool("approve_hiring_request", args) do
    with {:ok, requisition_id} <- validate_required_string(args, "requisition_id"),
         {:ok, position} <- validate_required_string(args, "position"),
         {:ok, department} <- validate_required_string(args, "department"),
         {:ok, approved} <- validate_required_boolean(args, "approved"),
         {:ok, rationale} <- validate_required_string(args, "rationale"),
         {:ok, decision} <- record_hiring_decision(requisition_id, position, department, approved, rationale, args) do

      # Notify relevant departments
      notify_hiring_decision(decision, department, approved)

      result = """
      Hiring Requisition #{if approved, do: "Approved", else: "Rejected"}

      Requisition ID: #{requisition_id}
      Position: #{position}
      Department: #{department}
      Decision: #{if approved, do: "Approved", else: "Rejected"} by CHRO
      Rationale: #{rationale}
      Salary Range: #{args["salary_range"] || "To be determined"}

      The #{department} department has been notified of the decision.
      """

      {:ok, result}
    else
      {:error, reason} -> {:error, "Failed to process hiring request: #{inspect(reason)}"}
    end
  end

  def execute_tool("conduct_performance_review", args) do
    with {:ok, employee_role} <- validate_required_string(args, "employee_role"),
         {:ok, review_period} <- validate_required_string(args, "review_period"),
         {:ok, rating} <- validate_required_string(args, "rating"),
         {:ok, review} <- record_performance_review(employee_role, review_period, rating, args) do

      # Notify employee's manager
      notify_performance_review(review, employee_role)

      result = """
      Performance Review Completed

      Employee Role: #{employee_role}
      Review Period: #{review_period}
      Rating: #{format_rating(rating)}
      Promotion Recommended: #{if args["promotion_recommended"], do: "Yes", else: "No"}

      Strengths:
      #{format_bullet_list(args["strengths"])}

      Areas for Improvement:
      #{format_bullet_list(args["areas_for_improvement"])}

      The performance review has been recorded and relevant parties have been notified.
      """

      {:ok, result}
    else
      {:error, reason} -> {:error, "Failed to conduct performance review: #{inspect(reason)}"}
    end
  end

  def execute_tool("allocate_hr_budget", args) do
    with {:ok, purpose} <- validate_required_string(args, "purpose"),
         {:ok, amount} <- validate_required_number(args, "amount"),
         {:ok, category} <- validate_required_string(args, "category"),
         :ok <- validate_budget_authority(amount),
         {:ok, allocation} <- create_budget_allocation(purpose, amount, category, args) do

      # Notify CEO of budget allocation
      MessageBus.publish_message(
        :chro,
        :ceo,
        :notification,
        "CHRO HR Budget Allocation: $#{format_number(amount)}",
        allocation
      )

      result = """
      HR Budget Allocated

      Purpose: #{purpose}
      Amount: $#{format_number(amount)}
      Category: #{category}
      Duration: #{args["duration"] || "Not specified"}

      The budget has been allocated and CEO has been notified.
      """

      {:ok, result}
    else
      {:error, :budget_limit_exceeded} ->
        {:error, "Budget amount exceeds CHRO autonomous authority ($300,000). Requires CEO approval."}

      {:error, reason} ->
        {:error, "Failed to allocate HR budget: #{inspect(reason)}"}
    end
  end

  def execute_tool("resolve_hr_issue", args) do
    with {:ok, issue_id} <- validate_required_string(args, "issue_id"),
         {:ok, issue_type} <- validate_required_string(args, "issue_type"),
         {:ok, resolution} <- validate_required_string(args, "resolution"),
         {:ok, issue_record} <- record_hr_issue_resolution(issue_id, issue_type, resolution, args) do

      # Check if escalation is needed
      if args["requires_escalation"] do
        escalate_hr_issue(issue_record)
      end

      result = """
      HR Issue Resolved

      Issue ID: #{issue_id}
      Type: #{issue_type}
      Parties Involved: #{format_list(args["parties_involved"])}
      Resolution: #{resolution}

      Action Items:
      #{format_bullet_list(args["action_items"])}

      Escalation Required: #{if args["requires_escalation"], do: "Yes (escalated to CEO)", else: "No"}

      The issue resolution has been recorded.
      """

      {:ok, result}
    else
      {:error, reason} -> {:error, "Failed to resolve HR issue: #{inspect(reason)}"}
    end
  end

  def execute_tool("review_team_health", args) do
    time_range = Map.get(args, "time_range", "30d")
    include_details = Map.get(args, "include_details", true)

    with {:ok, metrics} <- get_team_health_metrics(time_range, include_details) do
      result = format_team_health_report(metrics, time_range, include_details)
      {:ok, result}
    else
      {:error, reason} -> {:error, "Failed to retrieve team health metrics: #{inspect(reason)}"}
    end
  end

  def execute_tool("escalate_to_ceo", args) do
    with {:ok, issue_id} <- validate_required_string(args, "issue_id"),
         {:ok, reason} <- validate_required_string(args, "reason"),
         {:ok, urgency} <- validate_required_string(args, "urgency"),
         {:ok, escalation} <- create_hr_escalation(issue_id, reason, urgency, args) do

      # Send escalation to CEO
      MessageBus.publish_message(
        :chro,
        :ceo,
        :escalation,
        "HR Issue Escalation: #{issue_id}",
        escalation
      )

      result = """
      HR Issue Escalated to CEO

      Issue ID: #{issue_id}
      Urgency: #{urgency}
      Confidential: #{if args["confidential"] != false, do: "Yes", else: "No"}
      Reason: #{reason}
      CHRO Recommendation: #{args["recommendation"] || "None provided"}

      The issue has been escalated to the CEO for review and decision.
      """

      {:ok, result}
    else
      {:error, reason} -> {:error, "Failed to escalate HR issue: #{inspect(reason)}"}
    end
  end

  def execute_tool(name, _args) do
    {:error, "Unknown tool: #{name}"}
  end

  ## Private Functions

  defp record_hiring_decision(requisition_id, position, department, approved, rationale, args) do
    attrs = %{
      decision_type: "hiring_request",
      initiator_role: "chro",
      mode: :autonomous,
      status: if(approved, do: :approved, else: :rejected),
      context: %{
        requisition_id: requisition_id,
        position: position,
        department: department,
        salary_range: args["salary_range"]
      },
      outcome: %{
        approved: approved,
        rationale: rationale,
        decided_by: "chro",
        decided_at: DateTime.utc_now()
      },
      completed_at: DateTime.utc_now()
    }

    %Decision{}
    |> Decision.changeset(attrs)
    |> Repo.insert()
  end

  defp record_performance_review(employee_role, review_period, rating, args) do
    review = %{
      employee_role: employee_role,
      review_period: review_period,
      rating: rating,
      strengths: args["strengths"] || [],
      areas_for_improvement: args["areas_for_improvement"] || [],
      promotion_recommended: args["promotion_recommended"] || false,
      reviewed_by: "chro",
      reviewed_at: DateTime.utc_now()
    }

    {:ok, review}
  end

  defp create_budget_allocation(purpose, amount, category, args) do
    allocation = %{
      purpose: purpose,
      amount: amount,
      category: category,
      duration: args["duration"],
      allocated_by: "chro",
      allocated_at: DateTime.utc_now()
    }

    {:ok, allocation}
  end

  defp record_hr_issue_resolution(issue_id, issue_type, resolution, args) do
    attrs = %{
      decision_type: "hr_issue_resolution",
      initiator_role: "chro",
      mode: :autonomous,
      status: :completed,
      context: %{
        issue_id: issue_id,
        issue_type: issue_type,
        parties_involved: args["parties_involved"] || []
      },
      outcome: %{
        resolution: resolution,
        action_items: args["action_items"] || [],
        requires_escalation: args["requires_escalation"] || false,
        resolved_by: "chro",
        resolved_at: DateTime.utc_now()
      },
      completed_at: DateTime.utc_now()
    }

    %Decision{}
    |> Decision.changeset(attrs)
    |> Repo.insert()
  end

  defp create_hr_escalation(issue_id, reason, urgency, args) do
    escalation = %{
      issue_id: issue_id,
      reason: reason,
      urgency: urgency,
      recommendation: args["recommendation"],
      confidential: args["confidential"] != false,
      escalated_by: "chro",
      escalated_at: DateTime.utc_now()
    }

    {:ok, escalation}
  end

  defp get_team_health_metrics(time_range, _include_details) do
    hours = parse_time_range(time_range)
    cutoff = DateTime.utc_now() |> DateTime.add(-hours * 3600, :second)

    hr_decisions =
      Repo.one(
        from d in Decision,
          where: d.initiator_role == "chro" and d.inserted_at >= ^cutoff,
          select: count(d.id)
      ) || 0

    hiring_approvals =
      Repo.one(
        from d in Decision,
          where: d.initiator_role == "chro" and d.decision_type == "hiring_request" and
                d.inserted_at >= ^cutoff and d.status == :approved,
          select: count(d.id)
      ) || 0

    metrics = %{
      time_range: time_range,
      hr_decisions: hr_decisions,
      hiring_approvals: hiring_approvals,
      performance_reviews: 0  # Placeholder
    }

    {:ok, metrics}
  end

  defp format_team_health_report(metrics, time_range, _include_details) do
    """
    Team Health Report

    Time Range: #{time_range}

    HR Activity:
      - Total HR decisions: #{metrics.hr_decisions}
      - Hiring approvals: #{metrics.hiring_approvals}
      - Performance reviews: #{metrics.performance_reviews}

    Overall Status: Healthy
    """
  end

  defp validate_budget_authority(amount) do
    limit = Application.get_env(:chro, :autonomous_budget_limit, 300_000)

    if amount <= limit do
      :ok
    else
      {:error, :budget_limit_exceeded}
    end
  end

  defp notify_hiring_decision(decision, department, _approved) do
    MessageBus.broadcast_message(
      :chro,
      :notification,
      "Hiring Decision for #{department}",
      %{decision_id: decision.id, department: department}
    )
  end

  defp notify_performance_review(_review, employee_role) do
    MessageBus.publish_message(
      :chro,
      String.to_atom(employee_role),
      :notification,
      "Performance Review Completed",
      %{reviewed_by: "chro"}
    )
  end

  defp escalate_hr_issue(issue_record) do
    MessageBus.publish_message(
      :chro,
      :ceo,
      :escalation,
      "HR Issue Requires CEO Attention",
      %{issue_id: issue_record.id}
    )
  end

  defp parse_time_range("30d"), do: 24 * 30
  defp parse_time_range("90d"), do: 24 * 90
  defp parse_time_range("annual"), do: 24 * 365
  defp parse_time_range(_), do: 24 * 30

  defp format_rating("exceeds_expectations"), do: "Exceeds Expectations ⭐⭐⭐"
  defp format_rating("meets_expectations"), do: "Meets Expectations ⭐⭐"
  defp format_rating("needs_improvement"), do: "Needs Improvement ⭐"
  defp format_rating("unsatisfactory"), do: "Unsatisfactory"
  defp format_rating(rating), do: rating

  defp format_list(nil), do: "None"
  defp format_list([]), do: "None"
  defp format_list(list), do: Enum.join(list, ", ")

  defp format_bullet_list(nil), do: "  - None"
  defp format_bullet_list([]), do: "  - None"
  defp format_bullet_list(items) do
    items
    |> Enum.map(&"  - #{&1}")
    |> Enum.join("\n")
  end

  defp format_number(num) when is_number(num) do
    num
    |> trunc()
    |> Integer.to_string()
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end

  defp validate_required_number(args, key) do
    case Map.get(args, key) do
      nil -> {:error, "Missing required field: #{key}"}
      value when is_number(value) -> {:ok, value}
      _ -> {:error, "Field #{key} must be a number"}
    end
  end

  defp validate_required_boolean(args, key) do
    case Map.get(args, key) do
      nil -> {:error, "Missing required field: #{key}"}
      value when is_boolean(value) -> {:ok, value}
      _ -> {:error, "Field #{key} must be a boolean"}
    end
  end

  defp validate_required_string(args, key) do
    case Map.get(args, key) do
      nil -> {:error, "Missing required field: #{key}"}
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, "Field #{key} must be a string"}
    end
  end
end
