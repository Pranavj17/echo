#!/usr/bin/env elixir

# Test from CEO app context (matching training script)
alias EchoShared.LLM.DecisionHelper

IO.puts("Testing from CEO app context...")

# Test 1: Create session
case DecisionHelper.consult_session(:ceo, nil, "What is my role?") do
  {:ok, r1} ->
    IO.puts("SUCCESS:session=#{r1.session_id},turn=#{r1.turn_count},tokens=#{r1.total_tokens}")

    # Test 2: Continue
    case DecisionHelper.consult_session(:ceo, r1.session_id, "What are my priorities?") do
      {:ok, r2} ->
        IO.puts("SUCCESS:session=#{r2.session_id},turn=#{r2.turn_count},tokens=#{r2.total_tokens}")
        EchoShared.LLM.Session.end_session(r2.session_id)

      {:error, :session_not_found} ->
        IO.puts("FAIL:session_not_found for session #{r1.session_id}")

        # Debug: Check if session exists
        case EchoShared.LLM.Session.get_session(r1.session_id) do
          nil -> IO.puts("DEBUG:session not in ETS")
          s -> IO.puts("DEBUG:session exists in ETS, agent=#{s.agent_role}, turns=#{s.turn_count}")
        end

        # List all sessions
        sessions = EchoShared.LLM.Session.list_sessions()
        IO.puts("DEBUG:total sessions=#{length(sessions)}")

      _ ->
        IO.puts("FAIL:continuation")
    end

  _ ->
    IO.puts("FAIL:creation")
end
