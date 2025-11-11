defmodule EchoShared.LLM.Session do
  @moduledoc """
  Session-based LLM conversation management for ECHO agents.

  Provides LocalCode-style conversation memory with:
  - Automatic context injection (agent role, system status, recent activity)
  - Multi-turn conversation history (last 5 turns kept)
  - Context size tracking and warnings
  - Automatic session cleanup
  - **PostgreSQL persistence** - Sessions survive process restarts

  ## Usage

      # Create session and query
      {:ok, %{response: response, session_id: sid}} =
        Session.query(nil, "What should I do?", agent_role: :ceo)

      # Continue conversation (works across separate Mix runs)
      {:ok, %{response: response2}} =
        Session.query(sid, "Tell me more about that")

      # End session
      Session.end_session(sid)

  ## Session Lifecycle

  Sessions are stored in PostgreSQL and automatically:
  - Persist across process restarts
  - Cleaned up after 1 hour of inactivity
  - Warn when >10 turns (approaching context limit)
  - Warn when >4000 tokens (context getting large)
  """

  use GenServer
  require Logger

  alias EchoShared.LLM.{Client, Config, ContextBuilder}
  alias EchoShared.Repo
  alias EchoShared.Schemas.LlmSession
  import Ecto.Query

  @max_conversation_turns 5
  @session_timeout_ms :timer.hours(1)
  @cleanup_interval_ms :timer.minutes(15)
  @context_warning_tokens 4_000
  @context_limit_tokens 6_000

  ## Public API

  @doc """
  Start the session manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Query an LLM with conversation memory.

  ## Parameters

  - `session_id` - Existing session ID, or `nil` to create new session
  - `question` - The question to ask
  - `opts` - Options:
    - `:agent_role` - (Required if no session_id) Agent role atom
    - `:context` - Additional context for this query
    - `:temperature` - Override temperature
    - `:max_tokens` - Override max_tokens

  ## Returns

  - `{:ok, %{response: text, session_id: id, warnings: []}}` on success
  - `{:error, reason}` on failure

  ## Examples

      # Start new session
      {:ok, result} = Session.query(nil, "What's my role?", agent_role: :ceo)

      # Continue session
      {:ok, result} = Session.query(result.session_id, "What are my priorities?")
  """
  def query(session_id, question, opts \\ [])

  def query(nil, question, opts) do
    # Create new session
    agent_role = Keyword.fetch!(opts, :agent_role)

    unless Config.llm_enabled?(agent_role) do
      {:error, :llm_disabled}
    else
      session_id = generate_session_id(agent_role)
      session = create_session(session_id, agent_role, opts)

      do_query(session, question, opts)
    end
  end

  def query(session_id, question, opts) do
    case get_session(session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        do_query(session, question, opts)
    end
  end

  @doc """
  Get session details.

  Returns `nil` if session doesn't exist.
  """
  def get_session(session_id) do
    case Repo.get(LlmSession, session_id) do
      nil -> nil
      db_session -> LlmSession.to_session_struct(db_session)
    end
  end

  @doc """
  End a session and return archived conversation.

  Returns `{:ok, conversation_history}` or `{:error, :not_found}`.
  """
  def end_session(session_id) do
    case Repo.get(LlmSession, session_id) do
      nil ->
        {:error, :not_found}

      db_session ->
        session = LlmSession.to_session_struct(db_session)
        conversation = session.conversation_history

        # Delete from database
        Repo.delete(db_session)

        Logger.info("Session #{session_id} ended: #{session.turn_count} turns, ~#{session.total_tokens} tokens")

        {:ok, conversation}
    end
  end

  @doc """
  List all active sessions.
  """
  def list_sessions do
    Repo.all(LlmSession)
    |> Enum.map(fn db_session ->
      %{
        session_id: db_session.session_id,
        agent_role: String.to_atom(db_session.agent_role),
        turn_count: db_session.turn_count,
        total_tokens: db_session.total_tokens,
        created_at: db_session.created_at,
        last_query_at: db_session.last_query_at
      }
    end)
  end

  ## Private Functions

  defp do_query(session, question, opts) do
    # Build messages for LLM
    messages = build_messages(session, question, opts)

    # Estimate token count
    total_tokens = estimate_total_tokens(messages)

    # Check for context warnings
    warnings = check_context_warnings(session, total_tokens)

    # Get model and generation opts
    model = Config.get_model(session.agent_role)
    # Filter out session-specific opts, keep only generation opts (temperature, max_tokens)
    generation_opts = opts
                      |> Keyword.take([:temperature, :max_tokens])
                      |> Map.new()
    gen_opts = Config.get_generation_opts(session.agent_role, generation_opts)

    Logger.debug("#{session.agent_role} session #{session.session_id}: Query turn #{session.turn_count + 1}")

    # Query LLM
    case Client.chat(model, messages, gen_opts) do
      {:ok, response} ->
        # Update session
        updated_session = update_session(session, question, response, total_tokens)

        {:ok, %{
          response: response,
          session_id: session.session_id,
          turn_count: updated_session.turn_count,
          total_tokens: updated_session.total_tokens,
          warnings: warnings
        }}

      {:error, reason} ->
        Logger.warning("#{session.agent_role} session #{session.session_id}: Query failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_session(session_id, agent_role, _opts) do
    # Build startup context
    context = ContextBuilder.build_startup_context(agent_role)
    context_tokens = ContextBuilder.estimate_tokens(context)

    now = DateTime.utc_now()

    session = %{
      session_id: session_id,
      agent_role: agent_role,
      startup_context: context,
      conversation_history: [],
      turn_count: 0,
      total_tokens: context_tokens,
      created_at: now,
      last_query_at: now
    }

    # Convert to database format and insert
    attrs = LlmSession.from_session_struct(session)

    case %LlmSession{}
         |> LlmSession.changeset(attrs)
         |> Repo.insert() do
      {:ok, _db_session} ->
        Logger.info("Created session #{session_id} for #{agent_role}: ~#{context_tokens} context tokens")
        session

      {:error, changeset} ->
        Logger.error("Failed to create session: #{inspect(changeset.errors)}")
        raise "Session creation failed"
    end
  end

  defp build_messages(session, question, opts) do
    # System message with startup context
    system_message = %{
      role: "system",
      content: """
      #{Config.get_system_prompt(session.agent_role)}

      ## Project Context

      #{session.startup_context}

      You are currently in a multi-turn conversation. Use the conversation history below for context.
      """
    }

    # Add conversation history (last N turns)
    history_messages = Enum.flat_map(session.conversation_history, fn turn ->
      [
        %{role: "user", content: turn.question},
        %{role: "assistant", content: turn.response}
      ]
    end)

    # Current question with optional additional context
    user_message = if ctx = opts[:context] do
      """
      Context: #{ctx}

      Question: #{question}
      """
    else
      question
    end

    [system_message] ++ history_messages ++ [%{role: "user", content: user_message}]
  end

  defp update_session(session, question, response, total_tokens) do
    # Add turn to conversation history
    new_turn = %{
      question: question,
      response: response,
      timestamp: DateTime.utc_now()
    }

    # Keep only last N turns
    updated_history =
      ([new_turn | session.conversation_history])
      |> Enum.take(@max_conversation_turns)

    updated_session = %{session |
      conversation_history: updated_history,
      turn_count: session.turn_count + 1,
      total_tokens: total_tokens,
      last_query_at: DateTime.utc_now()
    }

    # Update in database
    db_session = Repo.get!(LlmSession, session.session_id)
    attrs = LlmSession.from_session_struct(updated_session)

    case db_session
         |> LlmSession.changeset(attrs)
         |> Repo.update() do
      {:ok, _} ->
        updated_session

      {:error, changeset} ->
        Logger.error("Failed to update session: #{inspect(changeset.errors)}")
        raise "Session update failed"
    end
  end

  defp estimate_total_tokens(messages) do
    # Rough estimate: 1 token ≈ 4 characters
    messages
    |> Enum.map(fn msg -> String.length(msg.content) end)
    |> Enum.sum()
    |> Kernel.div(4)
  end

  defp check_context_warnings(session, total_tokens) do
    warnings = []

    # Warn if approaching turn limit
    warnings = if session.turn_count >= 8 do
      ["Session has #{session.turn_count} turns. Consider ending session soon." | warnings]
    else
      warnings
    end

    # Warn if approaching context limit
    warnings = cond do
      total_tokens >= @context_limit_tokens ->
        ["Context size critical (#{total_tokens} tokens). Session will be slow. End and restart recommended." | warnings]

      total_tokens >= @context_warning_tokens ->
        ["Context size large (#{total_tokens} tokens). Session approaching limit." | warnings]

      true ->
        warnings
    end

    warnings
  end

  defp generate_session_id(agent_role) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random = :rand.uniform(999_999)
    "#{agent_role}_#{timestamp}_#{random}"
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("LLM Session manager started (PostgreSQL persistence)")

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup_sessions, state) do
    cleanup_old_sessions()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_sessions, @cleanup_interval_ms)
  end

  defp cleanup_old_sessions do
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, -@session_timeout_ms, :millisecond)

    # Delete old sessions in a single query
    {count, _} =
      from(s in LlmSession, where: s.last_query_at < ^cutoff)
      |> Repo.delete_all()

    if count > 0 do
      Logger.info("Cleaned up #{count} inactive sessions (last activity before #{cutoff})")
    end
  end
end
