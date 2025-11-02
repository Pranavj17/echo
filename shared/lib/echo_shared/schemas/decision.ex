defmodule EchoShared.Schemas.Decision do
  @moduledoc """
  Ecto schema for organizational decisions.

  Tracks all decisions made within the ECHO organization, including:
  - Autonomous decisions by individual agents
  - Collaborative decisions requiring consensus
  - Hierarchical decisions that were escalated
  - Human-in-the-loop decisions requiring approval
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "decisions" do
    field :decision_type, :string
    field :initiator_role, :string
    field :participants, {:array, :string}
    field :mode, Ecto.Enum, values: [:autonomous, :collaborative, :hierarchical, :human]
    field :context, :map
    field :status, Ecto.Enum,
      values: [:pending, :approved, :rejected, :escalated],
      default: :pending

    field :consensus_score, :float
    field :outcome, :map

    timestamps(type: :utc_datetime)
    field :completed_at, :utc_datetime
  end

  @doc """
  Changeset for creating a new decision.
  """
  def changeset(decision, attrs) do
    decision
    |> cast(attrs, [
      :decision_type,
      :initiator_role,
      :participants,
      :mode,
      :context,
      :status,
      :consensus_score,
      :outcome,
      :completed_at
    ])
    |> validate_required([:decision_type, :initiator_role, :mode, :context])
    |> validate_inclusion(:mode, [:autonomous, :collaborative, :hierarchical, :human])
    |> validate_inclusion(:status, [:pending, :approved, :rejected, :escalated])
  end
end
