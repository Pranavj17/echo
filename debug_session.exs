#!/usr/bin/env elixir

# Quick debug script to test session persistence
Application.ensure_all_started(:echo_shared)

alias EchoShared.LLM.{Session, DecisionHelper}

IO.puts("=== Session Debug Test ===\n")

# Test 1: Create session directly via Session module
IO.puts("Test 1: Direct Session.query with nil session_id")
result1 = Session.query(nil, "What is my role?", agent_role: :ceo)

case result1 do
  {:ok, r1} ->
    IO.puts("✓ Session created: #{r1.session_id}")
    IO.puts("  Turn count: #{r1.turn_count}")
    IO.puts("  Tokens: #{r1.total_tokens}")

    # Immediately check if session exists in ETS
    IO.puts("\nChecking ETS immediately after creation...")
    case Session.get_session(r1.session_id) do
      nil ->
        IO.puts("✗ ERROR: Session not found in ETS!")

      session ->
        IO.puts("✓ Session found in ETS")
        IO.puts("  Agent: #{session.agent_role}")
        IO.puts("  Turn count: #{session.turn_count}")
    end

    # Test 2: Continue conversation
    IO.puts("\nTest 2: Continue conversation with session_id")
    result2 = Session.query(r1.session_id, "What are my priorities?", [])

    case result2 do
      {:ok, r2} ->
        IO.puts("✓ Continuation succeeded")
        IO.puts("  Session: #{r2.session_id}")
        IO.puts("  Turn count: #{r2.turn_count}")
        IO.puts("  Tokens: #{r2.total_tokens}")

      {:error, :session_not_found} ->
        IO.puts("✗ ERROR: Session not found!")
        IO.puts("  Looking for: #{r1.session_id}")

        # Debug: List all sessions
        IO.puts("\n  All sessions in ETS:")
        sessions = Session.list_sessions()
        if Enum.empty?(sessions) do
          IO.puts("  (none)")
        else
          Enum.each(sessions, fn s ->
            IO.puts("    - #{s.session_id}")
          end)
        end

      {:error, reason} ->
        IO.puts("✗ ERROR: #{inspect(reason)}")
    end

  {:error, reason} ->
    IO.puts("✗ Failed to create session: #{inspect(reason)}")
end

IO.puts("\n=== End Debug Test ===")
