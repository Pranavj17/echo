#!/usr/bin/env elixir

# View messages between agents
# Usage: mix run scripts/view_messages.exs [from_role] [to_role]

alias EchoShared.Repo
alias EchoShared.Schemas.Message
import Ecto.Query

defmodule MessageViewer do
  @moduledoc """
  View messages exchanged between agents.
  """

  def run(args \\ []) do
    from_role = Enum.at(args, 0)
    to_role = Enum.at(args, 1)

    IO.puts("\n" <> IO.ANSI.blue() <> "═════════════════════════════════════════" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.blue() <> "  Agent Message History" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.blue() <> "═════════════════════════════════════════" <> IO.ANSI.reset() <> "\n")

    query = build_query(from_role, to_role)
    messages = Repo.all(query)

    if Enum.empty?(messages) do
      IO.puts(IO.ANSI.yellow() <> "No messages found" <> IO.ANSI.reset())
      show_help()
    else
      IO.puts("Found #{length(messages)} messages:\n")
      Enum.each(messages, &display_message/1)
    end
  end

  defp build_query(nil, nil) do
    from m in Message,
    order_by: [desc: m.inserted_at],
    limit: 20
  end

  defp build_query(from_role, nil) do
    from m in Message,
    where: m.from_role == ^from_role,
    order_by: [desc: m.inserted_at],
    limit: 20
  end

  defp build_query(from_role, to_role) do
    from m in Message,
    where: m.from_role == ^from_role and m.to_role == ^to_role,
    order_by: [desc: m.inserted_at],
    limit: 20
  end

  defp display_message(message) do
    type_color = case message.type do
      "request" -> IO.ANSI.yellow()
      "response" -> IO.ANSI.green()
      "notification" -> IO.ANSI.blue()
      "escalation" -> IO.ANSI.red()
      _ -> IO.ANSI.white()
    end

    IO.puts(type_color <> "┌─ [#{String.upcase(message.type)}] #{message.from_role} → #{message.to_role}" <> IO.ANSI.reset())
    IO.puts("│  Subject: #{message.subject}")
    IO.puts("│  Time: #{message.inserted_at}")

    # Display content
    content_text = case message.content do
      %{"content" => text} when is_binary(text) -> text
      text when is_binary(text) -> text
      map when is_map(map) -> inspect(map, pretty: true, limit: 200)
      _ -> inspect(message.content)
    end

    # Truncate if too long
    display_content = if String.length(content_text) > 300 do
      String.slice(content_text, 0..300) <> "..."
    else
      content_text
    end

    IO.puts("│  Content:")
    display_content
    |> String.split("\n")
    |> Enum.each(fn line -> IO.puts("│    #{line}") end)

    IO.puts("└" <> String.duplicate("─", 60) <> "\n")
  end

  defp show_help do
    IO.puts("\n" <> IO.ANSI.cyan() <> "Usage:" <> IO.ANSI.reset())
    IO.puts("  mix run scripts/view_messages.exs                    # View all recent messages")
    IO.puts("  mix run scripts/view_messages.exs ceo               # View messages from CEO")
    IO.puts("  mix run scripts/view_messages.exs ceo cto           # View CEO → CTO messages")
    IO.puts("")
  end
end

System.argv() |> MessageViewer.run()
