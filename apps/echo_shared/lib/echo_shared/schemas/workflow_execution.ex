defmodule EchoShared.Schemas.WorkflowExecution do
  @moduledoc """
  Ecto schema for workflow executions.

  Provides durable persistence for workflow state, enabling recovery
  after crashes and resumption of paused workflows.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  schema "workflow_executions" do
    field :workflow_name, :string
    field :status, Ecto.Enum,
      values: [:pending, :running, :paused, :completed, :failed],
      default: :running

    field :context, :map, default: %{}
    field :current_step, :integer, default: 0
    field :total_steps, :integer
    field :error, :string
    field :pause_reason, :string

    timestamps(type: :utc_datetime)
    field :completed_at, :utc_datetime
  end

  @doc """
  Changeset for creating a new workflow execution.
  """
  def changeset(execution, attrs) do
    execution
    |> cast(attrs, [
      :id,
      :workflow_name,
      :status,
      :context,
      :current_step,
      :total_steps,
      :error,
      :pause_reason,
      :completed_at
    ])
    |> validate_required([:id, :workflow_name])
    |> validate_inclusion(:status, [:pending, :running, :paused, :completed, :failed])
    |> unique_constraint(:id, name: :workflow_executions_pkey)
  end

  @doc """
  Convert to Execution struct for workflow engine.
  """
  def to_execution_struct(%__MODULE__{} = record) do
    %EchoShared.Workflow.Execution{
      id: record.id,
      workflow_name: record.workflow_name,
      status: record.status,
      context: record.context || %{},
      current_step: record.current_step || 0,
      pause_reason: record.pause_reason,
      error: record.error,
      started_at: record.inserted_at,
      completed_at: record.completed_at
    }
  end

  @doc """
  Create from Execution struct.
  """
  def from_execution_struct(%EchoShared.Workflow.Execution{} = exec) do
    %__MODULE__{
      id: exec.id,
      workflow_name: exec.workflow_name,
      status: exec.status,
      context: exec.context,
      current_step: exec.current_step,
      pause_reason: exec.pause_reason,
      error: if(exec.error, do: inspect(exec.error), else: nil),
      inserted_at: exec.started_at,
      completed_at: exec.completed_at
    }
  end
end
