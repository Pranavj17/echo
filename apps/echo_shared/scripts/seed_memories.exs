#!/usr/bin/env elixir

# Seed Sample Memories - Demonstrates parallel agent memory access
# Usage: mix run shared/scripts/seed_memories.exs

alias EchoShared.Repo
alias EchoShared.Schemas.Memory

defmodule SeedMemories do
  @moduledoc """
  Seeds the database with sample organizational memories from various agents.
  Demonstrates how agents running in parallel access shared memory.
  """

  def run do
    IO.puts("\n" <> IO.ANSI.blue() <> "Seeding ECHO Organizational Memory..." <> IO.ANSI.reset())
    IO.puts("─────────────────────────────────────────\n")

    # Clear existing memories (optional)
    clear_choice = IO.gets("Clear existing memories? (y/N): ") |> String.trim()
    if String.downcase(clear_choice) == "y" do
      Repo.delete_all(Memory)
      IO.puts(IO.ANSI.yellow() <> "Cleared existing memories" <> IO.ANSI.reset())
    end

    # Sample memories from different agents
    memories = [
      # CEO memories - Strategic
      %{
        key: "company_mission_2025",
        content: "Build the world's most advanced AI-powered organizational framework. Empower teams with autonomous agents that enhance human decision-making.",
        tags: ["strategy", "mission", "vision"],
        created_by_role: "ceo"
      },
      %{
        key: "q1_strategic_priorities",
        content: "1. Complete Phase 4 workflows, 2. Launch beta with 10 pilot customers, 3. Achieve 99.9% system uptime, 4. Expand engineering team by 5 members",
        tags: ["strategy", "okr", "q1-2025"],
        created_by_role: "ceo"
      },

      # CTO memories - Technical
      %{
        key: "tech_stack_decision_2025",
        content: "Primary stack: Elixir/OTP for agent runtime, PostgreSQL for persistence, Redis for message bus. Rationale: Fault tolerance, concurrency, and proven scalability.",
        tags: ["technology", "architecture", "decision"],
        created_by_role: "cto"
      },
      %{
        key: "infrastructure_guidelines",
        content: "All agents must be independently deployable. Use MCP protocol for standardization. Implement circuit breakers for external dependencies. Target 99.9% uptime SLA.",
        tags: ["infrastructure", "best-practices", "sla"],
        created_by_role: "cto"
      },

      # Senior Architect memories - Design
      %{
        key: "workflow_engine_design",
        content: "Workflow engine uses declarative DSL for multi-agent orchestration. Supports parallel execution, conditional branching, and human-in-the-loop approval. Built on OTP GenServer for fault tolerance.",
        tags: ["architecture", "workflows", "design"],
        created_by_role: "senior_architect"
      },
      %{
        key: "message_bus_pattern",
        content: "Inter-agent communication via Redis pub/sub. Private channels per agent (messages:role), broadcast channel (messages:all), leadership channel (messages:leadership). All messages persisted to PostgreSQL for audit trail.",
        tags: ["architecture", "messaging", "patterns"],
        created_by_role: "senior_architect"
      },

      # Product Manager memories - Product
      %{
        key: "feature_priority_matrix",
        content: "High priority: Workflow automation, AI-assisted decision-making, real-time collaboration. Medium: Advanced analytics, custom integrations. Low: UI customization, mobile apps.",
        tags: ["product", "roadmap", "priorities"],
        created_by_role: "product_manager"
      },
      %{
        key: "user_feedback_summary",
        content: "Pilot users love autonomous decision-making but want more visibility into agent reasoning. Feature request: explainable AI, decision audit trails, and rollback capabilities.",
        tags: ["product", "feedback", "user-research"],
        created_by_role: "product_manager"
      },

      # CHRO memories - People
      %{
        key: "team_composition_2025",
        content: "Current: 3 engineers, 1 product manager, 1 designer. Hiring plan: 5 senior engineers (Q1), 2 product managers (Q2), 1 DevOps engineer (Q1).",
        tags: ["hiring", "team", "headcount"],
        created_by_role: "chro"
      },

      # Operations Head memories - Operations
      %{
        key: "monitoring_setup",
        content: "Monitoring stack: Prometheus for metrics, Grafana for dashboards, PagerDuty for alerts. Key metrics: agent uptime, message latency, decision throughput, database query time.",
        tags: ["operations", "monitoring", "infrastructure"],
        created_by_role: "operations_head"
      },

      # Senior Developer memories - Implementation
      %{
        key: "coding_standards",
        content: "Follow Elixir style guide. Use dialyzer for type checking. Minimum 80% test coverage. All public functions must have @doc and @spec. Use with for happy path error handling.",
        tags: ["development", "standards", "best-practices"],
        created_by_role: "senior_developer"
      },

      # Test Lead memories - Quality
      %{
        key: "testing_strategy",
        content: "Three-tier testing: Unit tests for individual components, integration tests for multi-agent workflows, system tests for load/failover. Use ExUnit, property-based testing with StreamData.",
        tags: ["testing", "quality", "strategy"],
        created_by_role: "test_lead"
      },

      # Shared learnings
      %{
        key: "incident_2024_12_15_postmortem",
        content: "Database connection pool exhaustion during load test. Root cause: Missing connection timeout configuration. Fix: Added pool_size: 20, timeout: 15000. Prevention: Load testing before production deployment.",
        tags: ["incident", "postmortem", "lessons-learned"],
        created_by_role: "operations_head"
      }
    ]

    # Insert memories
    inserted = Enum.map(memories, fn attrs ->
      case %Memory{}
           |> Memory.changeset(attrs)
           |> Repo.insert() do
        {:ok, memory} ->
          IO.puts(IO.ANSI.green() <> "✓ " <> IO.ANSI.reset() <> "#{memory.key} (by #{memory.created_by_role})")
          memory

        {:error, changeset} ->
          IO.puts(IO.ANSI.red() <> "✗ Failed: #{attrs.key}" <> IO.ANSI.reset())
          IO.inspect(changeset.errors)
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    IO.puts("\n" <> IO.ANSI.blue() <> "═════════════════════════════════════════" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.green() <> "✓ Seeded #{length(inserted)} memories" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.blue() <> "═════════════════════════════════════════" <> IO.ANSI.reset())

    IO.puts("\n" <> IO.ANSI.cyan() <> "Next steps:" <> IO.ANSI.reset())
    IO.puts("  1. View all memories: mix run scripts/memory_viewer.exs list")
    IO.puts("  2. View by agent: mix run scripts/memory_viewer.exs by-agent")
    IO.puts("  3. Search memories: mix run scripts/memory_viewer.exs search 'workflow'")
    IO.puts("  4. View by tag: mix run scripts/memory_viewer.exs by-tag architecture")
    IO.puts("")
  end
end

SeedMemories.run()
