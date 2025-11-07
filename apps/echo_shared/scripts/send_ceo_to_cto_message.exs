#!/usr/bin/env elixir

# Send message from CEO to CTO
# Usage: mix run scripts/send_ceo_to_cto_message.exs

alias EchoShared.MessageBus

defmodule CEOtoCTOMessage do
  @moduledoc """
  Sends a message from CEO to CTO and monitors the response.
  Demonstrates how agents communicate and how CTO uses LLM to respond.
  """

  def run do
    IO.puts("\n" <> IO.ANSI.blue() <> "╔═══════════════════════════════════════════════════════╗" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.blue() <> "║      CEO → CTO Message Communication Demo            ║" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.blue() <> "╚═══════════════════════════════════════════════════════╝" <> IO.ANSI.reset() <> "\n")

    # Check if agents are running
    check_redis()

    # Get message from user
    subject = get_input("Message Subject", "Infrastructure Scaling Strategy for Q1")
    content = get_input("Message Content", "We need to discuss our infrastructure scaling strategy for Q1. With the planned customer growth, I want your technical perspective on whether we should expand our current Kubernetes cluster or explore serverless options. Please include cost estimates and timeline.")

    IO.puts("\n" <> IO.ANSI.yellow() <> "Sending message from CEO to CTO..." <> IO.ANSI.reset())

    # Generate unique message ID
    message_id = "msg_#{:erlang.unique_integer([:positive])}"

    # Create message
    message = %{
      "id" => message_id,
      "from" => "ceo",
      "to" => "cto",
      "type" => "request",
      "subject" => subject,
      "content" => content,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Send message via Redis
    case send_message(message) do
      {:ok, _} ->
        IO.puts(IO.ANSI.green() <> "✓ Message sent successfully!" <> IO.ANSI.reset())
        IO.puts("\nMessage Details:")
        IO.puts("  ID: #{message_id}")
        IO.puts("  From: CEO")
        IO.puts("  To: CTO")
        IO.puts("  Subject: #{subject}")
        IO.puts("\n" <> IO.ANSI.cyan() <> "Content:" <> IO.ANSI.reset())
        IO.puts("  #{content}")

        # Also save to database
        MessageBus.store_message_in_db("ceo", "cto", "request", subject, %{content: content})

        IO.puts("\n" <> IO.ANSI.yellow() <> "Waiting for CTO to process and respond..." <> IO.ANSI.reset())
        IO.puts("  (CTO will consult its LLM model and send a response)")
        IO.puts("\n" <> IO.ANSI.blue() <> "Check the logs to see:" <> IO.ANSI.reset())
        IO.puts("  - CTO receiving the message")
        IO.puts("  - CTO querying organizational memories")
        IO.puts("  - CTO consulting LLM (deepseek-coder:33b)")
        IO.puts("  - CTO sending response back to CEO")

        IO.puts("\n" <> IO.ANSI.green() <> "Monitor responses:" <> IO.ANSI.reset())
        IO.puts("  Database: mix run scripts/view_messages.exs")
        IO.puts("  Redis: redis-cli SUBSCRIBE messages:ceo")
        IO.puts("  CTO Log: tail -f logs/agents/cto.log")

      {:error, reason} ->
        IO.puts(IO.ANSI.red() <> "✗ Failed to send message: #{inspect(reason)}" <> IO.ANSI.reset())
    end

    IO.puts("")
  end

  defp check_redis do
    case Redix.command(:redix, ["PING"]) do
      {:ok, "PONG"} ->
        IO.puts(IO.ANSI.green() <> "✓ Redis connected" <> IO.ANSI.reset())

      _ ->
        IO.puts(IO.ANSI.red() <> "✗ Redis not available" <> IO.ANSI.reset())
        IO.puts("Make sure Redis is running and agents are started")
        System.halt(1)
    end
  end

  defp send_message(message) do
    channel = "messages:cto"
    payload = Jason.encode!(message)

    case Redix.command(:redix, ["PUBLISH", channel, payload]) do
      {:ok, subscribers} ->
        if subscribers > 0 do
          {:ok, subscribers}
        else
          {:error, "No subscribers (CTO agent may not be running)"}
        end

      error ->
        error
    end
  end

  defp get_input(prompt, default) do
    IO.write("\n" <> IO.ANSI.cyan() <> "#{prompt}" <> IO.ANSI.reset() <> " [#{default}]: ")
    case IO.gets("") |> String.trim() do
      "" -> default
      input -> input
    end
  end
end

CEOtoCTOMessage.run()
