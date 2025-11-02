defmodule EchoShared.Schemas.Memory do
  @moduledoc """
  Ecto schema for organizational memory.

  Stores shared knowledge across all ECHO agents including:
  - Organizational context and history
  - Workflow templates and procedures
  - Best practices and learnings
  - Strategic decisions and rationale
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "memories" do
    field :key, :string
    field :content, :string
    field :tags, {:array, :string}
    field :metadata, :map
    field :created_by_role, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a memory.
  """
  def changeset(memory, attrs) do
    memory
    |> cast(attrs, [:key, :content, :tags, :metadata, :created_by_role])
    |> validate_required([:key, :content])
    |> validate_length(:key, max: 255)
    |> validate_length(:content, min: 1, max: 100_000)
    |> unique_constraint(:key)
  end
end
