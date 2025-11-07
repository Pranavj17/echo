defmodule EchoShared.Repo.Migrations.AddMessageAcknowledgementFields do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :processed_at, :utc_datetime
      add :processing_error, :text
    end

    create index(:messages, [:to_role, :read, :inserted_at])
  end
end
