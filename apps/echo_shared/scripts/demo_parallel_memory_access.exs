#!/usr/bin/env elixir

# Demo: Parallel Agent Memory Access
# Demonstrates how multiple agents running in parallel query shared memory
# Usage: mix run shared/scripts/demo_parallel_memory_access.exs

alias EchoShared.Repo
alias EchoShared.Schemas.Memory
import Ecto.Query

defmodule ParallelMemoryDemo do
  @moduledoc """
  Simulates multiple agents querying shared memory in parallel.
  Shows how ECHO's organizational memory is accessed concurrently.
  """

  def run do
    IO.puts("\n" <> IO.ANSI.blue() <> "╔═══════════════════════════════════════════════════════╗" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.blue() <> "║  ECHO Parallel Agent Memory Access Demo              ║" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.blue() <> "╚═══════════════════════════════════════════════════════╝" <> IO.ANSI.reset() <> "\n")

    # Simulate parallel queries from different agents
    agents = [
      {:ceo, "What are our strategic priorities?", ["strategy", "okr"]},
      {:cto, "What technology decisions have been made?", ["technology", "architecture"]},
      {:product_manager, "What features are prioritized?", ["product", "roadmap"]},
      {:senior_architect, "What are the architecture patterns?", ["architecture", "patterns"]},
      {:test_lead, "What's our testing approach?", ["testing", "quality"]},
      {:operations_head, "How do we monitor the system?", ["operations", "monitoring"]}
    ]

    IO.puts(IO.ANSI.cyan() <> "Scenario: 6 agents query shared memory in parallel" <> IO.ANSI.reset())
    IO.puts("─────────────────────────────────────────\n")

    # Spawn parallel tasks for each agent
    start_time = System.monotonic_time(:millisecond)

    tasks = Enum.map(agents, fn {role, question, tags} ->
      Task.async(fn ->
        agent_query_memory(role, question, tags)
      end)
    end)

    # Wait for all tasks to complete
    results = Task.await_many(tasks, 5000)

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Display results
    Enum.each(results, fn {role, question, memories, query_time} ->
      display_agent_result(role, question, memories, query_time)
    end)

    # Summary
    IO.puts("\n" <> IO.ANSI.blue() <> "═════════════════════════════════════════" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.green() <> "✓ All agents completed queries in parallel" <> IO.ANSI.reset())
    IO.puts("Total time: #{duration}ms (parallel execution)")

    total_queries = length(results)
    avg_time = Enum.map(results, fn {_, _, _, t} -> t end) |> Enum.sum() |> div(total_queries)
    IO.puts("Average query time: #{avg_time}ms")
    IO.puts("Total memories accessed: #{Enum.map(results, fn {_, _, m, _} -> length(m) end) |> Enum.sum()}")
    IO.puts(IO.ANSI.blue() <> "═════════════════════════════════════════" <> IO.ANSI.reset() <> "\n")

    # Show concurrent access pattern
    demonstrate_concurrent_writes()
  end

  defp agent_query_memory(role, question, tags) do
    # Simulate agent querying memory by tags
    start_time = System.monotonic_time(:millisecond)

    memories = Repo.all(
      from m in Memory,
      where: fragment("? && ?", m.tags, ^tags),
      order_by: [desc: m.inserted_at]
    )

    end_time = System.monotonic_time(:millisecond)
    query_time = end_time - start_time

    # Simulate some processing time
    Process.sleep(:rand.uniform(50))

    {role, question, memories, query_time}
  end

  defp display_agent_result(role, question, memories, query_time) do
    IO.puts(IO.ANSI.green() <> "#{role |> to_string() |> String.upcase()}" <> IO.ANSI.reset())
    IO.puts("  Question: #{question}")
    IO.puts("  Found: #{length(memories)} relevant memories (#{query_time}ms)")

    Enum.take(memories, 2) |> Enum.each(fn memory ->
      IO.puts("    • #{memory.key}")
    end)

    IO.puts("")
  end

  defp demonstrate_concurrent_writes do
    IO.puts(IO.ANSI.cyan() <> "\nDemonstrating concurrent memory creation..." <> IO.ANSI.reset())
    IO.puts("─────────────────────────────────────────\n")

    # Simulate 3 agents creating memories concurrently
    write_tasks = [
      Task.async(fn ->
        create_memory("ceo_daily_standup_#{DateTime.utc_now() |> DateTime.to_unix()}",
                     "Daily standup notes: All teams on track, no blockers",
                     ["standup", "daily", "status"],
                     "ceo")
      end),
      Task.async(fn ->
        create_memory("senior_dev_code_review_#{DateTime.utc_now() |> DateTime.to_unix()}",
                     "Code review completed for PR #123: LGTM, approved for merge",
                     ["code-review", "development"],
                     "senior_developer")
      end),
      Task.async(fn ->
        create_memory("product_mgr_customer_call_#{DateTime.utc_now() |> DateTime.to_unix()}",
                     "Customer call notes: Requested export to CSV feature",
                     ["customer-feedback", "feature-request"],
                     "product_manager")
      end)
    ]

    write_results = Task.await_many(write_tasks, 5000)

    Enum.each(write_results, fn
      {:ok, memory} ->
        IO.puts(IO.ANSI.green() <> "✓ " <> IO.ANSI.reset() <> "Created: #{memory.key} (by #{memory.created_by_role})")
      {:error, reason} ->
        IO.puts(IO.ANSI.red() <> "✗ Failed: #{inspect(reason)}" <> IO.ANSI.reset())
    end)

    IO.puts("\n" <> IO.ANSI.cyan() <> "Concurrent writes completed successfully!" <> IO.ANSI.reset())
    IO.puts("PostgreSQL handles concurrent inserts with ACID guarantees.\n")
  end

  defp create_memory(key, content, tags, role) do
    # Simulate some processing before write
    Process.sleep(:rand.uniform(30))

    %Memory{}
    |> Memory.changeset(%{
      key: key,
      content: content,
      tags: tags,
      created_by_role: role,
      metadata: %{created_via: "parallel_demo", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
    |> Repo.insert()
  end
end

ParallelMemoryDemo.run()
