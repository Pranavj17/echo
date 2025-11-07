#!/usr/bin/env elixir

# Agent Memory Viewer - View and manage ECHO organizational memory
# Usage: mix run shared/scripts/memory_viewer.exs [command] [args]

alias EchoShared.Repo
alias EchoShared.Schemas.Memory
import Ecto.Query

defmodule MemoryViewer do
  @moduledoc """
  Utility for viewing and managing agent memories in the ECHO system.
  Shows how agents running in parallel access shared organizational memory.
  """

  def run(args \\ []) do
    command = Enum.at(args, 0, "list")

    case command do
      "list" -> list_all_memories()
      "count" -> count_memories()
      "by-agent" -> list_by_agent()
      "by-tag" -> list_by_tag(Enum.at(args, 1))
      "search" -> search_memories(Enum.at(args, 1))
      "add" -> add_memory(args)
      "help" -> show_help()
      _ ->
        IO.puts("Unknown command: #{command}")
        show_help()
    end
  end

  def list_all_memories do
    IO.puts("\n" <> IO.ANSI.blue() <> "═════════════════════════════════════════" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.blue() <> "  ECHO Organizational Memory" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.blue() <> "═════════════════════════════════════════" <> IO.ANSI.reset() <> "\n")

    memories = Repo.all(from m in Memory, order_by: [desc: m.inserted_at])

    if Enum.empty?(memories) do
      IO.puts(IO.ANSI.yellow() <> "No memories found in the database." <> IO.ANSI.reset())
      IO.puts("\nTip: Add a memory with: mix run shared/scripts/memory_viewer.exs add")
    else
      Enum.each(memories, &display_memory/1)
      IO.puts("\nTotal: #{length(memories)} memories")
    end
  end

  def count_memories do
    total = Repo.aggregate(Memory, :count)

    by_agent = Repo.all(
      from m in Memory,
      group_by: m.created_by_role,
      select: {m.created_by_role, count(m.id)}
    )

    IO.puts("\n" <> IO.ANSI.blue() <> "Memory Statistics" <> IO.ANSI.reset())
    IO.puts("─────────────────────────────────────────")
    IO.puts("Total Memories: #{total}")
    IO.puts("\nBy Agent:")

    Enum.each(by_agent, fn {role, count} ->
      IO.puts("  #{role || "unknown"}: #{count}")
    end)
  end

  def list_by_agent do
    agents = Repo.all(
      from m in Memory,
      distinct: m.created_by_role,
      select: m.created_by_role,
      order_by: m.created_by_role
    )

    IO.puts("\n" <> IO.ANSI.blue() <> "Memories by Agent" <> IO.ANSI.reset())
    IO.puts("─────────────────────────────────────────\n")

    Enum.each(agents, fn agent ->
      memories = Repo.all(
        from m in Memory,
        where: m.created_by_role == ^agent,
        order_by: [desc: m.inserted_at]
      )

      IO.puts(IO.ANSI.green() <> "#{agent || "Unknown"}" <> IO.ANSI.reset() <> " (#{length(memories)} memories)")
      Enum.each(memories, fn memory ->
        IO.puts("  • #{memory.key}")
      end)
      IO.puts("")
    end)
  end

  def list_by_tag(tag) when is_binary(tag) do
    memories = Repo.all(
      from m in Memory,
      where: ^tag in m.tags,
      order_by: [desc: m.inserted_at]
    )

    IO.puts("\n" <> IO.ANSI.blue() <> "Memories tagged: #{tag}" <> IO.ANSI.reset())
    IO.puts("─────────────────────────────────────────\n")

    if Enum.empty?(memories) do
      IO.puts(IO.ANSI.yellow() <> "No memories found with tag: #{tag}" <> IO.ANSI.reset())
    else
      Enum.each(memories, &display_memory/1)
      IO.puts("\nTotal: #{length(memories)} memories")
    end
  end

  def list_by_tag(nil) do
    IO.puts(IO.ANSI.red() <> "Error: Please provide a tag name" <> IO.ANSI.reset())
    IO.puts("Usage: mix run shared/scripts/memory_viewer.exs by-tag <tag_name>")
  end

  def search_memories(query) when is_binary(query) do
    pattern = "%#{query}%"

    memories = Repo.all(
      from m in Memory,
      where: ilike(m.content, ^pattern) or ilike(m.key, ^pattern),
      order_by: [desc: m.inserted_at]
    )

    IO.puts("\n" <> IO.ANSI.blue() <> "Search Results for: #{query}" <> IO.ANSI.reset())
    IO.puts("─────────────────────────────────────────\n")

    if Enum.empty?(memories) do
      IO.puts(IO.ANSI.yellow() <> "No memories found matching: #{query}" <> IO.ANSI.reset())
    else
      Enum.each(memories, &display_memory/1)
      IO.puts("\nTotal: #{length(memories)} results")
    end
  end

  def search_memories(nil) do
    IO.puts(IO.ANSI.red() <> "Error: Please provide a search query" <> IO.ANSI.reset())
    IO.puts("Usage: mix run shared/scripts/memory_viewer.exs search <query>")
  end

  def add_memory(args) do
    IO.puts("\n" <> IO.ANSI.blue() <> "Add New Memory" <> IO.ANSI.reset())
    IO.puts("─────────────────────────────────────────\n")

    key = get_input("Memory key (unique identifier): ", Enum.at(args, 1))
    content = get_input("Content: ", Enum.at(args, 2))
    tags_input = get_input("Tags (comma-separated): ", Enum.at(args, 3))
    agent = get_input("Created by agent role: ", Enum.at(args, 4))

    tags = String.split(tags_input, ",") |> Enum.map(&String.trim/1)

    attrs = %{
      key: key,
      content: content,
      tags: tags,
      created_by_role: agent,
      metadata: %{}
    }

    case %Memory{}
         |> Memory.changeset(attrs)
         |> Repo.insert() do
      {:ok, memory} ->
        IO.puts("\n" <> IO.ANSI.green() <> "✓ Memory created successfully!" <> IO.ANSI.reset())
        display_memory(memory)

      {:error, changeset} ->
        IO.puts("\n" <> IO.ANSI.red() <> "✗ Failed to create memory:" <> IO.ANSI.reset())
        IO.inspect(changeset.errors)
    end
  end

  defp display_memory(memory) do
    IO.puts(IO.ANSI.cyan() <> "┌─ #{memory.key}" <> IO.ANSI.reset())
    IO.puts("│  Content: #{truncate(memory.content, 100)}")
    IO.puts("│  Tags: #{inspect(memory.tags)}")
    IO.puts("│  Created by: #{memory.created_by_role || "unknown"}")
    IO.puts("│  Created at: #{memory.inserted_at}")
    if memory.metadata && map_size(memory.metadata) > 0 do
      IO.puts("│  Metadata: #{inspect(memory.metadata)}")
    end
    IO.puts("└" <> String.duplicate("─", 50) <> "\n")
  end

  defp truncate(text, length) do
    if String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text
    end
  end

  defp get_input(prompt, default \\ nil) do
    if default do
      default
    else
      IO.write(prompt)
      IO.gets("") |> String.trim()
    end
  end

  def show_help do
    IO.puts("\n" <> IO.ANSI.blue() <> "ECHO Memory Viewer" <> IO.ANSI.reset())
    IO.puts("═════════════════════════════════════════\n")
    IO.puts("View and manage shared organizational memory accessed by")
    IO.puts("all agents running in parallel.\n")
    IO.puts(IO.ANSI.green() <> "Commands:" <> IO.ANSI.reset())
    IO.puts("  list           - List all memories")
    IO.puts("  count          - Show memory statistics")
    IO.puts("  by-agent       - List memories grouped by agent")
    IO.puts("  by-tag <tag>   - List memories with specific tag")
    IO.puts("  search <query> - Search memories by content or key")
    IO.puts("  add            - Add a new memory interactively")
    IO.puts("  help           - Show this help message")
    IO.puts("\n" <> IO.ANSI.green() <> "Examples:" <> IO.ANSI.reset())
    IO.puts("  mix run shared/scripts/memory_viewer.exs list")
    IO.puts("  mix run shared/scripts/memory_viewer.exs by-tag strategy")
    IO.puts("  mix run shared/scripts/memory_viewer.exs search 'product launch'")
    IO.puts("")
  end
end

# Run the viewer
System.argv() |> MemoryViewer.run()
