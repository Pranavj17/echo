defmodule EchoShared.Repo.Migrations.CreateFlowExecutions do
  use Ecto.Migration

  def change do
    create table(:flow_executions, primary_key: false) do
      add :id, :string, primary_key: true
      add :flow_module, :string, null: false
      add :status, :string, null: false, default: "pending"

      # State and execution tracking
      add :state, :map, default: %{}
      add :current_step, :string
      add :current_trigger, :string

      # Routing history
      add :route_taken, {:array, :string}, default: []
      add :completed_steps, {:array, :string}, default: []

      # Agent coordination
      add :awaited_response, :map

      # Error handling
      add :error, :text
      add :pause_reason, :string

      timestamps(type: :utc_datetime)
      add :completed_at, :utc_datetime
    end

    create index(:flow_executions, [:status])
    create index(:flow_executions, [:flow_module])
    create index(:flow_executions, [:inserted_at])
  end
end
