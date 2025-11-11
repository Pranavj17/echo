defmodule EchoShared.Repo.Migrations.CreateLlmSessions do
  use Ecto.Migration

  def change do
    create table(:llm_sessions, primary_key: false) do
      add :session_id, :string, primary_key: true
      add :agent_role, :string, null: false
      add :startup_context, :text
      add :conversation_history, :jsonb, default: "[]"
      add :turn_count, :integer, default: 0
      add :total_tokens, :integer, default: 0
      add :created_at, :utc_datetime, null: false
      add :last_query_at, :utc_datetime, null: false
    end

    create index(:llm_sessions, [:agent_role])
    create index(:llm_sessions, [:last_query_at])
    create index(:llm_sessions, [:created_at])
  end
end
