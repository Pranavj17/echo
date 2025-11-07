defmodule EchoShared.Workflow.Execution do
  @moduledoc """
  Workflow execution state tracking.

  Tracks the progress and state of a workflow execution.
  """

  @type status :: :pending | :running | :paused | :completed | :failed

  @type t :: %__MODULE__{
    id: String.t(),
    workflow_name: String.t(),
    status: status(),
    context: map(),
    current_step: integer(),
    total_steps: integer(),
    pause_reason: String.t() | nil,
    error: term() | nil,
    started_at: DateTime.t(),
    completed_at: DateTime.t() | nil
  }

  defstruct [
    :id,
    :workflow_name,
    :status,
    :context,
    :current_step,
    :total_steps,
    :pause_reason,
    :error,
    :started_at,
    :completed_at
  ]

  @doc """
  Create a new execution.
  """
  def new(id, workflow_name, context \\ %{}) do
    %__MODULE__{
      id: id,
      workflow_name: workflow_name,
      status: :pending,
      context: context,
      current_step: 0,
      started_at: DateTime.utc_now()
    }
  end

  @doc """
  Update execution status.
  """
  def update_status(execution, new_status) do
    %{execution | status: new_status}
  end

  @doc """
  Advance to next step.
  """
  def next_step(execution) do
    %{execution | current_step: execution.current_step + 1}
  end

  @doc """
  Mark execution as completed.
  """
  def complete(execution) do
    %{execution |
      status: :completed,
      completed_at: DateTime.utc_now()
    }
  end

  @doc """
  Mark execution as failed.
  """
  def fail(execution, error) do
    %{execution |
      status: :failed,
      error: error,
      completed_at: DateTime.utc_now()
    }
  end
end
