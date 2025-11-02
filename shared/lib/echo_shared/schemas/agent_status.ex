defmodule EchoShared.Schemas.AgentStatus do
  @moduledoc """
  Ecto schema for agent health monitoring.

  Tracks the status and health of all ECHO agents in the organization.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:role, :string, autogenerate: false}

  schema "agent_status" do
    field :status, Ecto.Enum, values: [:running, :stopped, :error], default: :running
    field :last_heartbeat, :utc_datetime
    field :version, :string
    field :capabilities, {:array, :string}
    field :metadata, :map
  end

  @doc """
  Changeset for updating agent status.
  """
  def changeset(agent_status, attrs) do
    agent_status
    |> cast(attrs, [:role, :status, :last_heartbeat, :version, :capabilities, :metadata])
    |> validate_required([:role, :status, :last_heartbeat])
    |> validate_inclusion(:status, [:running, :stopped, :error])
  end
end
