defmodule EchoShared.Repo.Migrations.CreateBaseTables do
  use Ecto.Migration

  def change do
    # Decisions table
    create table(:decisions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :decision_type, :string, null: false
      add :initiator_role, :string, null: false
      add :participants, {:array, :string}
      add :mode, :string, null: false
      add :context, :map, null: false
      add :status, :string, null: false, default: "pending"
      add :consensus_score, :float
      add :outcome, :map

      timestamps(type: :utc_datetime)
      add :completed_at, :utc_datetime
    end

    create index(:decisions, [:initiator_role])
    create index(:decisions, [:status])
    create index(:decisions, [:decision_type])

    # Messages table
    create table(:messages) do
      add :from_role, :string, null: false
      add :to_role, :string, null: false
      add :type, :string, null: false
      add :subject, :string, null: false
      add :content, :map, null: false
      add :metadata, :map
      add :read, :boolean, default: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:messages, [:to_role, :inserted_at])
    create index(:messages, [:from_role, :inserted_at])
    create index(:messages, [:to_role, :read])

    # Memories table
    create table(:memories, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :key, :string, null: false
      add :content, :text, null: false
      add :tags, {:array, :string}, null: false
      add :metadata, :map
      add :created_by_role, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:memories, [:key])
    create index(:memories, [:tags], using: "GIN")
    create index(:memories, [:created_by_role])

    # Decision votes table
    create table(:decision_votes) do
      add :decision_id, references(:decisions, type: :uuid, on_delete: :delete_all), null: false
      add :voter_role, :string, null: false
      add :vote, :string, null: false
      add :rationale, :text
      add :confidence, :float, null: false
      add :voted_at, :utc_datetime, null: false
    end

    create unique_index(:decision_votes, [:decision_id, :voter_role])
    create index(:decision_votes, [:decision_id])

    # Agent status table
    create table(:agent_status, primary_key: false) do
      add :role, :string, primary_key: true
      add :status, :string, null: false
      add :last_heartbeat, :utc_datetime, null: false
      add :version, :string
      add :capabilities, :map
      add :metadata, :map
    end

    create index(:agent_status, [:last_heartbeat])
  end
end
