defmodule EchoShared.Repo.Migrations.CreateDelegatorSessions do
  use Ecto.Migration

  def change do
    create table(:delegator_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, :string, null: false
      add :task_category, :string, null: false
      add :task_description, :text
      add :active_agents, {:array, :string}, default: []
      add :context, :map, default: %{}
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :total_agents_spawned, :integer, default: 0
      add :tasks_delegated, :integer, default: 0
      add :status, :string, default: "active"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:delegator_sessions, [:session_id])
    create index(:delegator_sessions, [:started_at])
    create index(:delegator_sessions, [:status])
    create index(:delegator_sessions, [:task_category])
  end
end
