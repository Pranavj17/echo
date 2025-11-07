#!/usr/bin/env elixir

# ECHO Day 1 Simulation Script
#
# This script executes the feature_development workflow to simulate
# a realistic Day 1 organizational scenario with all 9 agents.
#
# Prerequisites:
# 1. PostgreSQL running (localhost:5432)
# 2. Redis running (localhost:6379)
# 3. Database 'echo_org' created with migrations run
# 4. All 9 agent escripts built
#
# Usage:
#   cd /Users/pranav/Documents/echo/shared
#   mix run ../scripts/day1_simulation.exs

defmodule Day1Simulator do
  def run() do
    IO.puts """
    ================================================================================
    ECHO Day 1 Simulation - Mobile App Dashboard Feature
    ================================================================================

    Scenario: Product team wants to build a new mobile dashboard feature.
    This workflow will coordinate all 9 agents to design, approve, and implement
    the feature following proper organizational hierarchy and decision patterns.

    """

    # Load the feature development workflow
    IO.puts "Loading feature_development workflow..."
    {workflow, _} = Code.eval_file("../workflows/examples/feature_development.exs")

    IO.puts "✓ Workflow loaded: #{workflow.name}"
    IO.puts "  Participants: #{Enum.join(workflow.participants, ", ")}"
    IO.puts "  Total steps: #{length(workflow.steps)}"
    IO.puts ""

    # Validate workflow
    case EchoShared.Workflow.Definition.validate(workflow) do
      {:ok, _} ->
        IO.puts "✓ Workflow validation passed"
      {:error, reason} ->
        IO.puts "✗ Workflow validation failed: #{inspect(reason)}"
        System.halt(1)
    end

    # Execute workflow with context
    IO.puts "\nStarting workflow execution..."
    context = %{
      feature_name: "Mobile App Dashboard",
      description: "Real-time dashboard for mobile app with charts and analytics",
      priority: "high",
      estimated_budget: 150_000,
      complexity: "high",
      target_release: "Q1 2025",
      expected_users: 50_000
    }

    case EchoShared.Workflow.Engine.execute_workflow(workflow, context) do
      {:ok, execution_id} ->
        IO.puts "✓ Workflow started: #{execution_id}"
        IO.puts ""

        # Monitor execution
        IO.puts "Monitoring workflow execution..."
        IO.puts "(Workflow is running asynchronously in the background)"
        IO.puts ""

        # Poll for status updates
        monitor_workflow(execution_id, 30, 1000)

      {:error, reason} ->
        IO.puts "✗ Failed to start workflow: #{inspect(reason)}"
        System.halt(1)
    end
  end

  defp monitor_workflow(execution_id, max_attempts, interval_ms, attempt \\ 1) do
  if attempt > max_attempts do
    IO.puts "\n⚠ Workflow monitoring timeout after #{max_attempts} attempts"
    IO.puts "  Check workflow status manually with:"
    IO.puts "  EchoShared.Workflow.Engine.get_status(\"#{execution_id}\")"
    System.halt(1)
  end

  case EchoShared.Workflow.Engine.get_status(execution_id) do
    {:ok, execution} ->
      print_status(execution, attempt)

      case execution.status do
        :completed ->
          IO.puts "\n" <> String.duplicate("=", 80)
          IO.puts "✓ Workflow completed successfully!"
          print_summary(execution)
          System.halt(0)

        :failed ->
          IO.puts "\n" <> String.duplicate("=", 80)
          IO.puts "✗ Workflow failed!"
          IO.puts "  Error: #{inspect(execution.error)}"
          System.halt(1)

        :paused ->
          IO.puts "\n" <> String.duplicate("=", 80)
          IO.puts "⏸ Workflow paused for human approval"
          IO.puts "  Reason: #{execution.pause_reason}"
          IO.puts ""
          IO.puts "To resume, run:"
          IO.puts "  EchoShared.Workflow.Engine.resume_workflow(\"#{execution_id}\", %{approved: true})"
          System.halt(0)

        :running ->
          # Continue monitoring
          Process.sleep(interval_ms)
          monitor_workflow(execution_id, max_attempts, interval_ms, attempt + 1)
      end

    {:error, :not_found} ->
      IO.puts "✗ Execution not found: #{execution_id}"
      System.halt(1)
  end
end

defp print_status(execution, attempt) do
  progress = "Step #{execution.current_step}"
  IO.write "\r[#{String.pad_leading(Integer.to_string(attempt), 2, "0")}] Status: #{execution.status} | Progress: #{progress}   "
end

defp print_summary(execution) do
  duration = if execution.completed_at && execution.started_at do
    diff = DateTime.diff(execution.completed_at, execution.started_at, :second)
    "#{diff} seconds"
  else
    "unknown"
  end

  IO.puts "  Workflow: #{execution.workflow_name}"
  IO.puts "  Duration: #{duration}"
  IO.puts "  Steps completed: #{execution.current_step}"
  IO.puts "  Context: #{inspect(execution.context, pretty: true)}"
  IO.puts String.duplicate("=", 80)
  IO.puts ""
  IO.puts "Feature Development Complete! 🎉"
  IO.puts ""
  IO.puts "Next steps:"
  IO.puts "  1. Review decision records in PostgreSQL"
  IO.puts "  2. Check Redis message bus activity logs"
  IO.puts "  3. Verify all agent communications"
  IO.puts "  4. Run: psql -h localhost -U postgres echo_org -c 'SELECT * FROM workflow_executions;'"
end
end

# Run the simulation
Day1Simulator.run()
