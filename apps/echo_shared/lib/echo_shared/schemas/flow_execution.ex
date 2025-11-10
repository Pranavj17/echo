defmodule EchoShared.Schemas.FlowExecution do
  @moduledoc """
  Ecto schema for Flow executions.

  Extends WorkflowExecution with Flow-specific state tracking:
  - Router decisions and route labels
  - Current step/listener being executed
  - Completed steps for tracking progress
  - Agent responses awaited

  ## State Flow

  1. Flow starts → execute @start functions
  2. After each step → check for @router
  3. Router returns label → find @listen(label)
  4. Execute listener → repeat from step 2

  ## Integration with Redis

  When a listener publishes a message to an agent:
  - Store awaited_response: {agent_role, request_id}
  - FlowCoordinator listens on messages:{agent_role}
  - On response → update state and continue flow
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  schema "flow_executions" do
    field :flow_module, :string
    field :status, Ecto.Enum,
      values: [:pending, :running, :waiting_agent, :paused, :completed, :failed],
      default: :pending

    # Current execution state
    field :state, :map, default: %{}
    field :current_step, :string        # Current step function name
    field :current_trigger, :string     # What triggered this step (label or step name)

    # Routing history
    field :route_taken, {:array, :string}, default: []  # History of router decisions
    field :completed_steps, {:array, :string}, default: []

    # Agent coordination
    field :awaited_response, :map  # %{agent: :ceo, request_id: "req_123"}

    # Error handling
    field :error, :string
    field :pause_reason, :string

    # Optimistic locking - prevents race conditions
    field :version, :integer, default: 1

    timestamps(type: :utc_datetime)
    field :completed_at, :utc_datetime
  end

  @doc """
  Changeset for creating/updating flow execution.

  ## Optimistic Locking
  Uses version field to prevent race conditions when multiple processes
  try to update the same flow execution simultaneously.
  """
  def changeset(execution, attrs) do
    execution
    |> cast(attrs, [
      :id,
      :flow_module,
      :status,
      :state,
      :current_step,
      :current_trigger,
      :route_taken,
      :completed_steps,
      :awaited_response,
      :error,
      :pause_reason,
      :completed_at,
      :version
    ])
    |> validate_required([:id, :flow_module, :status])
    |> validate_inclusion(:status, [:pending, :running, :waiting_agent, :paused, :completed, :failed])
    |> unique_constraint(:id, name: :flow_executions_pkey)
    |> optimistic_lock(:version)
  end

  @doc """
  Mark step as completed.
  """
  def complete_step(execution, step_name) do
    change(execution, %{
      completed_steps: [step_name | (execution.completed_steps || [])]
    })
  end

  @doc """
  Record router decision.
  """
  def record_route(execution, label) do
    change(execution, %{
      route_taken: [label | (execution.route_taken || [])],
      current_trigger: label
    })
  end

  @doc """
  Mark as waiting for agent response.
  """
  def await_agent_response(execution, agent, request_id) do
    change(execution, %{
      status: :waiting_agent,
      awaited_response: %{agent: agent, request_id: request_id}
    })
  end

  @doc """
  Resume after receiving agent response.
  """
  def receive_agent_response(execution, response) do
    # Merge response into state
    new_state = Map.put(execution.state, "agent_response", response)

    change(execution, %{
      status: :running,
      state: new_state,
      awaited_response: nil
    })
  end

  @doc """
  Mark flow as completed.
  """
  def complete(execution) do
    change(execution, %{
      status: :completed,
      completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Mark flow as failed.
  """
  def fail(execution, error_message) do
    change(execution, %{
      status: :failed,
      error: error_message,
      completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end
end
