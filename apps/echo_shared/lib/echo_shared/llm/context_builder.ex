defmodule EchoShared.LLM.ContextBuilder do
  @moduledoc """
  Builds agent-specific context for LLM queries.

  Similar to LocalCode's context_builder.sh, this module injects:
  - ECHO project overview (role-specific excerpt)
  - Agent role, responsibilities, and authority
  - Current system status (infrastructure, agents)
  - Recent decisions made by this agent
  - Recent messages to/from this agent
  - Git context (branch, recent commits)

  ## Usage

      context = ContextBuilder.build_startup_context(:ceo)
      # => "# ECHO Context for CEO\n\n## Your Role\n..."

      tokens = ContextBuilder.estimate_tokens(context)
      # => 1876
  """

  require Logger

  alias EchoShared.{Repo, Schemas.Decision, Schemas.Message}
  import Ecto.Query

  @echo_overview """
  # ECHO (Executive Coordination & Hierarchical Organization)

  Multi-agent AI organizational model where 9 autonomous role-based agents
  communicate via Model Context Protocol (MCP). Each agent is an independent
  MCP server that can connect to Claude Desktop or other MCP clients.

  **Architecture:**
  - 9 Independent Agent MCP Servers (CEO, CTO, CHRO, Ops, PM, Architect, UI/UX, Dev, Test)
  - PostgreSQL for persistent state (decisions, messages, memories, votes)
  - Redis for real-time pub/sub messaging
  - Ollama for local LLM inference (9 specialized models)

  **Technology Stack:**
  - Language: Elixir/OTP 27
  - Database: PostgreSQL 16
  - Message Bus: Redis 7
  - Protocol: MCP 2024-11-05 (JSON-RPC 2.0 over stdio)
  - AI Models: Ollama (local, specialized per agent)

  **Decision Modes:**
  1. Autonomous - Agent decides within authority limits
  2. Collaborative - Multiple agents vote for consensus
  3. Hierarchical - Escalates up reporting chain
  4. Human-in-the-Loop - Critical decisions need human approval
  """

  @agent_role_details %{
    ceo: %{
      title: "Chief Executive Officer",
      responsibilities: [
        "Strategic leadership and company direction",
        "High-level budget approvals (up to $1M autonomous)",
        "Crisis management and major decisions",
        "Stakeholder alignment and organizational health",
        "Long-term planning and risk assessment"
      ],
      authority: %{
        budget_limit: 1_000_000,
        can_approve: ["strategic_initiatives", "major_investments", "reorganizations"],
        reports_to: "Board of Directors / Humans"
      },
      collaborates_with: [:cto, :chro, :operations_head, :product_manager]
    },
    cto: %{
      title: "Chief Technology Officer",
      responsibilities: [
        "Technology strategy and architecture decisions",
        "Infrastructure and deployment approvals",
        "Technical debt management",
        "Engineering excellence and scalability",
        "Security and compliance oversight"
      ],
      authority: %{
        can_approve: ["architecture_decisions", "infrastructure_changes", "tech_stack"],
        requires_escalation: ["major_migrations", "security_incidents"]
      },
      collaborates_with: [:ceo, :senior_architect, :operations_head, :senior_developer]
    },
    chro: %{
      title: "Chief Human Resources Officer",
      responsibilities: [
        "Talent acquisition and retention",
        "Team dynamics and culture",
        "Professional development and training",
        "Performance management",
        "Organizational wellbeing"
      ],
      authority: %{
        can_approve: ["hiring", "training_budgets", "team_changes"],
        requires_escalation: ["layoffs", "major_restructuring"]
      },
      collaborates_with: [:ceo, :operations_head]
    },
    operations_head: %{
      title: "Head of Operations",
      responsibilities: [
        "Day-to-day operations efficiency",
        "Resource allocation and optimization",
        "Process improvement and automation",
        "Vendor management",
        "Operational metrics tracking"
      ],
      authority: %{
        can_approve: ["process_changes", "vendor_contracts", "resource_allocation"],
        requires_escalation: ["major_process_overhauls", "large_contracts"]
      },
      collaborates_with: [:ceo, :cto, :chro]
    },
    product_manager: %{
      title: "Product Manager",
      responsibilities: [
        "Product strategy and roadmap",
        "Feature prioritization",
        "User research and feedback analysis",
        "Product-market fit validation",
        "Stakeholder communication"
      ],
      authority: %{
        can_approve: ["feature_prioritization", "minor_scope_changes"],
        requires_escalation: ["major_pivots", "sunset_products"]
      },
      collaborates_with: [:ceo, :senior_architect, :uiux_engineer, :senior_developer]
    },
    senior_architect: %{
      title: "Senior Architect",
      responsibilities: [
        "System design and architecture",
        "Technical specifications and patterns",
        "API design and contracts",
        "Scalability and performance planning",
        "Integration architecture"
      ],
      authority: %{
        can_approve: ["design_patterns", "api_contracts", "module_architecture"],
        requires_escalation: ["system_wide_rewrites", "major_tech_changes"]
      },
      collaborates_with: [:cto, :senior_developer, :product_manager]
    },
    uiux_engineer: %{
      title: "UI/UX Engineer",
      responsibilities: [
        "User interface design and implementation",
        "User experience optimization",
        "Design system maintenance",
        "Accessibility compliance",
        "Visual design and branding"
      ],
      authority: %{
        can_approve: ["ui_changes", "design_patterns", "accessibility_fixes"],
        requires_escalation: ["brand_changes", "major_redesigns"]
      },
      collaborates_with: [:product_manager, :senior_developer]
    },
    senior_developer: %{
      title: "Senior Developer",
      responsibilities: [
        "Feature implementation and coding",
        "Code quality and best practices",
        "Bug fixes and maintenance",
        "Code reviews and mentoring",
        "Performance optimization"
      ],
      authority: %{
        can_approve: ["implementation_details", "refactoring", "bug_fixes"],
        requires_escalation: ["architecture_changes", "breaking_changes"]
      },
      collaborates_with: [:senior_architect, :test_lead, :uiux_engineer]
    },
    test_lead: %{
      title: "Test Lead",
      responsibilities: [
        "Test strategy and planning",
        "Test case design and execution",
        "Quality assurance and metrics",
        "Regression testing",
        "CI/CD pipeline quality gates"
      ],
      authority: %{
        can_approve: ["test_plans", "quality_gates", "test_automation"],
        requires_escalation: ["release_blocking_issues", "critical_bugs"]
      },
      collaborates_with: [:senior_developer, :cto, :operations_head]
    }
  }

  @doc """
  Build startup context for an agent role.

  Returns a formatted string with:
  - Project overview
  - Agent role and responsibilities
  - Current system status
  - Recent decisions (last 5)
  - Recent messages (last 5)
  - Git context

  ## Parameters

  - `agent_role` - Agent role atom (:ceo, :cto, etc.)

  ## Returns

  String containing full context (~1500-2500 tokens)
  """
  def build_startup_context(agent_role) do
    role_details = Map.get(@agent_role_details, agent_role, %{})

    """
    #{@echo_overview}

    ## Your Role: #{role_details[:title] || agent_role}

    **Responsibilities:**
    #{format_list(role_details[:responsibilities] || [])}

    **Authority:**
    #{format_authority(role_details[:authority] || %{})}

    **Key Collaborators:**
    #{format_list(role_details[:collaborates_with] || [])}

    #{build_system_status()}

    #{build_recent_activity(agent_role)}

    #{build_git_context()}

    ---

    You are #{role_details[:title] || agent_role} in this conversation.
    Use your expertise and decision-making authority as appropriate.
    """
    |> String.trim()
  end

  @doc """
  Estimate token count for text.

  Uses rough heuristic: 1 token ≈ 4 characters
  """
  def estimate_tokens(text) when is_binary(text) do
    String.length(text) |> div(4)
  end

  def estimate_tokens(_), do: 0

  ## Private Functions

  defp build_system_status do
    # This would ideally check actual system health
    # For now, return static context
    """
    ## Current System Status

    **Infrastructure:**
    - PostgreSQL: Running (echo_org database)
    - Redis: Running (message bus on port 6383)
    - Ollama: Running (local LLM server)

    **Active Agents:** 9 agents (CEO, CTO, CHRO, Operations, PM, Architect, UI/UX, Developer, Test Lead)

    **Database Channels:**
    - decisions: Organizational decisions with voting
    - messages: Inter-agent communication
    - memories: Shared organizational knowledge
    - agent_status: Agent health monitoring
    """
  end

  defp build_recent_activity(agent_role) do
    role_str = Atom.to_string(agent_role)

    # Get last 5 decisions by this agent
    recent_decisions = try do
      from(d in Decision,
        where: d.initiator_role == ^role_str,
        order_by: [desc: d.inserted_at],
        limit: 5,
        select: %{
          type: d.decision_type,
          status: d.status,
          mode: d.mode,
          created: d.inserted_at
        }
      )
      |> Repo.all()
    rescue
      _ -> []
    end

    # Get last 5 messages to/from this agent
    recent_messages = try do
      from(m in Message,
        where: m.from_role == ^role_str or m.to_role == ^role_str,
        order_by: [desc: m.inserted_at],
        limit: 5,
        select: %{
          from: m.from_role,
          to: m.to_role,
          type: m.type,
          subject: m.subject,
          created: m.inserted_at
        }
      )
      |> Repo.all()
    rescue
      _ -> []
    end

    """
    ## Your Recent Activity

    **Recent Decisions (last 5):**
    #{format_decisions(recent_decisions)}

    **Recent Messages (last 5):**
    #{format_messages(recent_messages, role_str)}
    """
  end

  defp build_git_context do
    # Try to get git context - fail gracefully if not available
    branch = System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true)
             |> elem(0)
             |> String.trim()
             |> case do
               "" -> "unknown"
               b -> b
             end

    last_commit = System.cmd("git", ["log", "-1", "--oneline"], stderr_to_stdout: true)
                  |> elem(0)
                  |> String.trim()
                  |> case do
                    "" -> "No commits"
                    c -> c
                  end

    """
    ## Git Context

    **Current Branch:** #{branch}
    **Last Commit:** #{last_commit}
    """
  rescue
    _ ->
      """
      ## Git Context

      **Current Branch:** unknown
      **Last Commit:** unknown
      """
  end

  defp format_list([]), do: "  (none)"
  defp format_list(items) do
    items
    |> Enum.map(fn item -> "  - #{item}" end)
    |> Enum.join("\n")
  end

  defp format_authority(authority) do
    parts = []

    parts = if budget = authority[:budget_limit] do
      ["  - Budget Authority: $#{format_number(budget)}" | parts]
    else
      parts
    end

    parts = if approvals = authority[:can_approve] do
      ["  - Can Approve: #{Enum.join(approvals, ", ")}" | parts]
    else
      parts
    end

    parts = if escalations = authority[:requires_escalation] do
      ["  - Requires Escalation: #{Enum.join(escalations, ", ")}" | parts]
    else
      parts
    end

    parts = if reports_to = authority[:reports_to] do
      ["  - Reports To: #{reports_to}" | parts]
    else
      parts
    end

    case parts do
      [] -> "  (standard authority)"
      _ -> Enum.reverse(parts) |> Enum.join("\n")
    end
  end

  defp format_decisions([]), do: "  No recent decisions"
  defp format_decisions(decisions) do
    decisions
    |> Enum.map(fn d ->
      date = format_datetime(d.created)
      "  - [#{d.status}] #{d.type} (#{d.mode} mode) - #{date}"
    end)
    |> Enum.join("\n")
  end

  defp format_messages([], _role), do: "  No recent messages"
  defp format_messages(messages, agent_role) do
    messages
    |> Enum.map(fn m ->
      direction = if m.from == agent_role, do: "→ #{m.to}", else: "← #{m.from}"
      date = format_datetime(m.created)
      "  - #{direction}: #{m.subject} (#{m.type}) - #{date}"
    end)
    |> Enum.join("\n")
  end

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  rescue
    _ -> "unknown"
  end

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.reverse()
    |> String.to_charlist()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(num), do: inspect(num)
end
