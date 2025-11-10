defmodule EchoShared.Repo.Migrations.AddVersionToFlowExecutions do
  use Ecto.Migration

  def change do
    alter table(:flow_executions) do
      add :version, :integer, default: 1, null: false
    end

    create index(:flow_executions, [:version])
  end
end
