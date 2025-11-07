defmodule EchoShared.Repo.Migrations.CreateWorkflowExecutions do
  use Ecto.Migration

  def change do
    create table(:workflow_executions, primary_key: false) do
      add :id, :string, primary_key: true
      add :workflow_name, :string, null: false
      add :status, :string, null: false, default: "running"
      add :context, :map, default: %{}
      add :current_step, :integer, default: 0
      add :total_steps, :integer
      add :error, :text
      add :pause_reason, :string

      timestamps(type: :utc_datetime)
      add :completed_at, :utc_datetime
    end

    create index(:workflow_executions, [:status])
    create index(:workflow_executions, [:workflow_name])
    create index(:workflow_executions, [:inserted_at])
  end
end
