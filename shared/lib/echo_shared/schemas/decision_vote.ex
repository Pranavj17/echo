defmodule EchoShared.Schemas.DecisionVote do
  @moduledoc """
  Ecto schema for collaborative decision votes.

  Tracks individual agent votes during collaborative consensus decision-making.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "decision_votes" do
    belongs_to :decision, EchoShared.Schemas.Decision
    field :voter_role, :string
    field :vote, Ecto.Enum, values: [:approve, :reject, :abstain]
    field :rationale, :string
    field :confidence, :float

    field :voted_at, :utc_datetime
  end

  @doc """
  Changeset for recording a vote.
  """
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:decision_id, :voter_role, :vote, :rationale, :confidence, :voted_at])
    |> validate_required([:decision_id, :voter_role, :vote, :confidence])
    |> validate_inclusion(:vote, [:approve, :reject, :abstain])
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint([:decision_id, :voter_role])
  end
end
