defmodule EchoShared.Schemas.LlmSession do
  @moduledoc """
  Ecto schema for persistent LLM conversation sessions.

  Stores multi-turn conversation history in PostgreSQL to enable
  session persistence across process restarts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:session_id, :string, autogenerate: false}
  @derive {Jason.Encoder, only: [:session_id, :agent_role, :startup_context,
                                  :conversation_history, :turn_count, :total_tokens,
                                  :created_at, :last_query_at]}

  schema "llm_sessions" do
    field :agent_role, :string
    field :startup_context, :string
    field :conversation_history, {:array, :map}, default: []
    field :turn_count, :integer, default: 0
    field :total_tokens, :integer, default: 0
    field :created_at, :utc_datetime
    field :last_query_at, :utc_datetime
  end

  @doc """
  Changeset for creating or updating a session.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_id,
      :agent_role,
      :startup_context,
      :conversation_history,
      :turn_count,
      :total_tokens,
      :created_at,
      :last_query_at
    ])
    |> validate_required([:session_id, :agent_role, :created_at, :last_query_at])
    |> validate_number(:turn_count, greater_than_or_equal_to: 0)
    |> validate_number(:total_tokens, greater_than_or_equal_to: 0)
  end

  @doc """
  Convert from Session struct to map suitable for database insert.
  """
  def from_session_struct(%{
    session_id: session_id,
    agent_role: agent_role,
    startup_context: startup_context,
    conversation_history: conversation_history,
    turn_count: turn_count,
    total_tokens: total_tokens,
    created_at: created_at,
    last_query_at: last_query_at
  }) do
    %{
      session_id: session_id,
      agent_role: to_string(agent_role),
      startup_context: startup_context,
      conversation_history: conversation_history,
      turn_count: turn_count,
      total_tokens: total_tokens,
      created_at: created_at,
      last_query_at: last_query_at
    }
  end

  @doc """
  Convert from database schema to Session struct.
  """
  def to_session_struct(%__MODULE__{} = db_session) do
    # Convert conversation history string keys to atom keys
    conversation_history = Enum.map(db_session.conversation_history, fn turn ->
      %{
        question: turn["question"],
        response: turn["response"],
        timestamp: parse_timestamp(turn["timestamp"])
      }
    end)

    %{
      session_id: db_session.session_id,
      agent_role: String.to_atom(db_session.agent_role),
      startup_context: db_session.startup_context,
      conversation_history: conversation_history,
      turn_count: db_session.turn_count,
      total_tokens: db_session.total_tokens,
      created_at: db_session.created_at,
      last_query_at: db_session.last_query_at
    }
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()
  defp parse_timestamp(%DateTime{} = dt), do: dt
  defp parse_timestamp(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end
end
