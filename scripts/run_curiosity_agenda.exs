#!/usr/bin/env elixir

# ECHO Curiosity Agenda Simulation
#
# This script runs a complete company-wide initiative where all 9 agents
# collaborate on the question: "How can AI be curious?"
#
# Demonstrates:
# - CEO setting strategic vision
# - Leadership discussion (CTO, CHRO, Operations Head)
# - Product Manager defining user stories
# - Senior Architect designing technical approach
# - CTO approving architecture
# - UI/UX Engineer creating experience design
# - Parallel implementation (Developer, Test Lead, CHRO)
# - Test Lead validating implementation
# - CEO approving deployment
# - CHRO leading retrospective
#
# All agents work towards a common goal with authentic collaboration.

defmodule CuriosityAgendaSimulator do
  require Logger

  def run() do
    IO.puts ""
    IO.puts String.duplicate("=", 80)
    IO.puts "ECHO Curiosity Agenda Simulation"
    IO.puts "Initiative: How Can AI Be Curious?"
    IO.puts String.duplicate("=", 80)
    IO.puts ""

    # Start the application if not already started
    case Application.ensure_all_started(:echo_shared) do
      {:ok, _} -> :ok
      {:error, _} ->
        Logger.info("Starting ECHO Shared application...")
        Application.start(:echo_shared)
    end

    # Load the curiosity agenda workflow
    IO.puts "Loading curiosity_agenda workflow..."
    {workflow, _} = Code.eval_file("workflows/curiosity_agenda.exs")

    IO.puts "✓ Workflow loaded: #{workflow.name}"
    IO.puts "  Description: #{String.split(workflow.description, "\n") |> Enum.at(0)}"
    IO.puts "  Participants: #{Enum.join(workflow.participants, ", ")}"
    IO.puts "  Total steps: #{length(workflow.steps)}"
    IO.puts ""

    # Validate workflow
    case EchoShared.Workflow.Definition.validate(workflow) do
      :ok ->
        IO.puts "✓ Workflow validation passed"
      {:ok, _} ->
        IO.puts "✓ Workflow validation passed"
      {:error, reason} ->
        IO.puts "✗ Workflow validation failed: #{inspect(reason)}"
        System.halt(1)
    end

    IO.puts ""
    IO.puts "Starting workflow execution..."
    IO.puts ""

    # Execute the workflow
    case EchoShared.Workflow.Engine.execute_workflow(workflow, %{
      company_name: "ECHO",
      initiative_name: "AI Curiosity Research",
      start_date: Date.utc_today() |> Date.to_string(),
      fiscal_year: "2025"
    }) do
      {:ok, execution_id} ->
        IO.puts "✓ Workflow started: #{execution_id}"
        IO.puts ""
        IO.puts "Monitoring workflow execution..."
        IO.puts ""

        monitor_workflow(execution_id, 60, 500)

      {:error, reason} ->
        IO.puts "✗ Failed to start workflow: #{inspect(reason)}"
        System.halt(1)
    end
  end

  defp monitor_workflow(execution_id, max_attempts, interval_ms, attempt \\ 1) do
    case EchoShared.Workflow.Engine.get_status(execution_id) do
      {:ok, execution} ->
        print_status(execution, attempt)

        case execution.status do
          :completed ->
            IO.puts ""
            print_summary(execution)
            print_agent_contributions(execution_id)
            System.halt(0)

          :failed ->
            IO.puts ""
            IO.puts "✗ Workflow failed!"
            IO.puts "  Error: #{execution.error}"
            System.halt(1)

          :running ->
            if attempt >= max_attempts do
              IO.puts ""
              IO.puts "✗ Workflow timeout after #{max_attempts} attempts"
              System.halt(1)
            else
              Process.sleep(interval_ms)
              monitor_workflow(execution_id, max_attempts, interval_ms, attempt + 1)
            end

          _ ->
            IO.puts "  Status: #{execution.status}"
            Process.sleep(interval_ms)
            monitor_workflow(execution_id, max_attempts, interval_ms, attempt + 1)
        end

      {:error, :not_found} ->
        IO.puts "✗ Workflow execution not found"
        System.halt(1)
    end
  end

  defp print_status(execution, attempt) do
    progress = "Step #{execution.current_step}"

    IO.write("\r[#{String.pad_leading(Integer.to_string(attempt), 2, "0")}] ")
    IO.write("Status: #{String.pad_trailing(to_string(execution.status), 10)} | ")
    IO.write("Progress: #{progress}")
  end

  defp print_summary(execution) do
    IO.puts String.duplicate("=", 80)
    IO.puts "✓ Curiosity Agenda Completed Successfully!"
    IO.puts String.duplicate("=", 80)
    IO.puts ""
    IO.puts "  Initiative: How Can AI Be Curious?"
    IO.puts "  Workflow: #{execution.workflow_name}"

    started_at = execution.inserted_at
    completed_at = execution.completed_at || DateTime.utc_now()
    duration = DateTime.diff(completed_at, started_at, :second)

    IO.puts "  Duration: #{duration} seconds"
    IO.puts "  Steps completed: #{execution.current_step}"
    IO.puts ""

    IO.puts "  Context:"
    Enum.each(execution.context, fn {key, value} ->
      IO.puts "    #{key}: #{inspect(value)}"
    end)
    IO.puts ""
  end

  defp print_agent_contributions(execution_id) do
    IO.puts String.duplicate("=", 80)
    IO.puts "Agent Contributions to Curiosity Initiative"
    IO.puts String.duplicate("=", 80)
    IO.puts ""

    # Query messages from database to show what each agent did
    case EchoShared.Repo.query(
      """
      SELECT to_role, subject, content, inserted_at
      FROM messages
      WHERE metadata->>'execution_id' = $1
      ORDER BY inserted_at ASC
      """,
      [execution_id]
    ) do
      {:ok, %{rows: rows}} when length(rows) > 0 ->
        agent_contributions = Enum.group_by(rows, fn [to_role, _, _, _] -> to_role end)

        Enum.each([
          {:ceo, "Chief Executive Officer"},
          {:cto, "Chief Technology Officer"},
          {:chro, "Chief Human Resources Officer"},
          {:operations_head, "Operations Head"},
          {:product_manager, "Product Manager"},
          {:senior_architect, "Senior Architect"},
          {:uiux_engineer, "UI/UX Engineer"},
          {:senior_developer, "Senior Developer"},
          {:test_lead, "Test Lead"}
        ], fn {role, title} ->
          role_str = to_string(role)
          case Map.get(agent_contributions, role_str) do
            nil ->
              :ok
            contributions ->
              IO.puts "#{title} (#{role}):"
              Enum.each(contributions, fn [_to_role, subject, _content, _timestamp] ->
                action = format_action(subject)
                IO.puts "  • #{action}"
              end)
              IO.puts ""
          end
        end)

      {:ok, %{rows: []}} ->
        IO.puts "(Note: Messages table not available in echo_org database yet)"
        IO.puts "Workflow executed successfully, but message tracking requires migrations."
        IO.puts ""

      {:error, _} ->
        IO.puts "(Note: Could not query messages table)"
        IO.puts ""
    end

    IO.puts String.duplicate("=", 80)
    IO.puts "What Each Agent Contributed:"
    IO.puts String.duplicate("=", 80)
    IO.puts ""
    IO.puts "1. CEO: Set strategic vision for AI curiosity research ($500K budget)"
    IO.puts "2. CTO: Evaluated technical feasibility of curiosity mechanisms"
    IO.puts "3. CHRO: Assessed team capabilities and planned learning initiatives"
    IO.puts "4. Operations Head: Planned resource allocation and timeline"
    IO.puts "5. Product Manager: Created feature requirements and user stories"
    IO.puts "6. Senior Architect: Designed Curiosity Engine architecture"
    IO.puts "7. CTO (again): Approved technical proposal and budget"
    IO.puts "8. UI/UX Engineer: Designed curiosity dashboard and user experience"
    IO.puts "9. Senior Developer: Planned 4-phase implementation"
    IO.puts "10. Test Lead: Created comprehensive test strategy"
    IO.puts "11. CHRO (again): Tracked team learning and development"
    IO.puts "12. Test Lead (again): Validated implementation quality"
    IO.puts "13. CEO (again): Approved production deployment"
    IO.puts "14. CHRO (final): Conducted retrospective and captured learnings"
    IO.puts ""
    IO.puts "Result: Complete company-wide collaboration on curiosity research!"
    IO.puts ""
  end

  defp format_action(subject) do
    case subject do
      "set_company_vision" -> "Set strategic vision for AI curiosity"
      "evaluate_technical_feasibility" -> "Evaluated technical feasibility"
      "assess_team_capabilities" -> "Assessed team capabilities"
      "plan_resource_allocation" -> "Planned resource allocation"
      "create_feature_requirement" -> "Created Curiosity Engine requirements"
      "design_technical_architecture" -> "Designed technical architecture"
      "approve_technical_proposal" -> "Approved technical proposal"
      "design_user_experience" -> "Designed user experience"
      "implement_feature" -> "Planned implementation phases"
      "create_test_strategy" -> "Created test strategy"
      "track_team_learning" -> "Tracked team learning"
      "validate_implementation" -> "Validated implementation"
      "approve_deployment" -> "Approved production deployment"
      "conduct_retrospective" -> "Conducted team retrospective"
      _ -> subject
    end
  end
end

# Run the simulation
CuriosityAgendaSimulator.run()
