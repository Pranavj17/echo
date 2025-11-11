defmodule EchoShared.LLM.Session do
  @moduledoc """
  Session-based LLM conversation management for ECHO agents.

  Provides LocalCode-style conversation memory with:
  - Automatic context injection (agent role, system status, recent activity)
  - Multi-turn conversation history (last 5 turns kept)
  - Context size tracking and warnings
  - Automatic session cleanup

  ## Usage

      # Create session and query
      {:ok, %{response: response, session_id: sid}} =
        Session.query(nil, "What should I do?", agent_role: :ceo)

      # Continue conversation
      {:ok, %{response: response2}} =
        Session.query(sid, "Tell me more about that")

      # End session
      Session.end_session(sid)

  ## Session Lifecycle

  Sessions are stored in ETS and automatically:
  - Cleaned up after 1 hour of inactivity
  - Warn when >10 turns (approaching context limit)
  - Warn when >4000 tokens (context getting large)
  """

  use GenServer
  require Logger

  alias EchoShared.LLM.{Client, Config, ContextBuilder}

  @table_name :llm_sessions
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
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, session}] -> session
      [] -> nil
    end
  end

  @doc """
  End a session and return archived conversation.

  Returns `{:ok, conversation_history}` or `{:error, :not_found}`.
  """
  def end_session(session_id) do
    case get_session(session_id) do
      nil ->
        {:error, :not_found}

      session ->
        # Archive conversation
        conversation = session.conversation_history

        # Remove from ETS
        :ets.delete(@table_name, session_id)

        Logger.info("Session #{session_id} ended: #{session.turn_count} turns, ~#{session.total_tokens} tokens")

        {:ok, conversation}
    end
  end

  @doc """
  List all active sessions.
  """
  def list_sessions do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {session_id, session} ->
      %{
        session_id: session_id,
        agent_role: session.agent_role,
        turn_count: session.turn_count,
        total_tokens: session.total_tokens,
        created_at: session.created_at,
        last_query_at: session.last_query_at
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

    session = %{
      session_id: session_id,
      agent_role: agent_role,
      startup_context: context,
      conversation_history: [],
      turn_count: 0,
      total_tokens: context_tokens,
      created_at: DateTime.utc_now(),
      last_query_at: DateTime.utc_now()
    }

    :ets.insert(@table_name, {session_id, session})

    Logger.info("Created session #{session_id} for #{agent_role}: ~#{context_tokens} context tokens")

    session
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

    :ets.insert(@table_name, {session.session_id, updated_session})

    updated_session
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
    # Create ETS table for sessions
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("LLM Session manager started")

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

    :ets.tab2list(@table_name)
    |> Enum.filter(fn {_id, session} ->
      DateTime.compare(session.last_query_at, cutoff) == :lt
    end)
    |> Enum.each(fn {session_id, session} ->
      Logger.info("Cleaning up inactive session #{session_id} (last activity: #{session.last_query_at})")
      :ets.delete(@table_name, session_id)
    end)
  end
end
