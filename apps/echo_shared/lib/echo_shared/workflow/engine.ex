defmodule EchoShared.Workflow.Engine do
  @moduledoc """
  Workflow orchestration engine for ECHO agents.

  Coordinates multi-agent workflows with support for:
  - Sequential execution
  - Parallel execution
  - Conditional branching
  - Human-in-the-loop pauses
  - Timeouts and error handling
  """

  use GenServer
  require Logger

  alias EchoShared.Workflow.Execution
  alias EchoShared.Schemas.WorkflowExecution
  alias EchoShared.MessageBus
  alias EchoShared.Repo

  import Ecto.Query

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start a workflow execution.
  """
  def execute_workflow(workflow_definition, context \\ %{}) do
    GenServer.call(__MODULE__, {:execute, workflow_definition, context}, 30_000)
  end

  @doc """
  Get workflow execution status.
  """
  def get_status(execution_id) do
    GenServer.call(__MODULE__, {:get_status, execution_id})
  end

  @doc """
  Resume a paused workflow (human approval).
  """
  def resume_workflow(execution_id, approval_data) do
    GenServer.call(__MODULE__, {:resume, execution_id, approval_data})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Workflow Engine started")

    # Load in-flight workflows from database (recovery after crash)
    in_flight_executions = load_in_flight_workflows()

    Logger.info("Recovered #{map_size(in_flight_executions)} in-flight workflows")

    {:ok, %{executions: in_flight_executions}}
  end

  @impl true
  def handle_call({:execute, workflow_def, context}, _from, state) do
    execution_id = generate_execution_id()

    Logger.info("Starting workflow: #{workflow_def.name} (#{execution_id})")

    execution = %Execution{
      id: execution_id,
      workflow_name: workflow_def.name,
      status: :running,
      context: context,
      current_step: 0,
      total_steps: length(workflow_def.steps),
      started_at: DateTime.utc_now()
    }

    # Persist to database
    case persist_execution(execution) do
      {:ok, _} ->
        # Store execution in memory
        new_state = put_in(state, [:executions, execution_id], execution)

        # Start executing steps asynchronously
        Task.start(fn -> execute_steps(workflow_def, execution) end)

        {:reply, {:ok, execution_id}, new_state}

      {:error, reason} ->
        Logger.error("Failed to persist workflow execution: #{inspect(reason)}")
        {:reply, {:error, :persistence_failed}, state}
    end
  end

  @impl true
  def handle_call({:get_status, execution_id}, _from, state) do
    case Map.get(state.executions, execution_id) do
      nil -> {:reply, {:error, :not_found}, state}
      execution -> {:reply, {:ok, execution}, state}
    end
  end

  @impl true
  def handle_call({:resume, execution_id, approval_data}, _from, state) do
    case Map.get(state.executions, execution_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      execution ->
        updated_execution = %{execution |
          status: :running,
          context: Map.merge(execution.context, approval_data)
        }
        new_state = put_in(state, [:executions, execution_id], updated_execution)
        {:reply, :ok, new_state}
    end
  end

  ## Private Functions

  defp execute_steps(workflow_def, execution) do
    Logger.info("Executing #{length(workflow_def.steps)} steps for #{workflow_def.name}")

    result =
      Enum.reduce_while(workflow_def.steps, {:ok, execution}, fn step, {:ok, exec} ->
        case execute_step(step, exec, workflow_def) do
          {:ok, updated_exec} -> {:cont, {:ok, updated_exec}}
          {:pause, updated_exec} -> {:halt, {:pause, updated_exec}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case result do
      {:ok, final_exec} ->
        Logger.info("Workflow #{workflow_def.name} completed successfully")
        update_execution_status(final_exec.id, :completed)

      {:pause, paused_exec} ->
        Logger.info("Workflow #{workflow_def.name} paused for human input")
        update_execution_status(paused_exec.id, :paused)

      {:error, reason} ->
        Logger.error("Workflow #{workflow_def.name} failed: #{inspect(reason)}")
        update_execution_status(execution.id, :failed)
    end
  end

  defp execute_step(step, execution, _workflow_def) do
    Logger.info("Executing step #{execution.current_step}: #{inspect(step)}")

    # Execute the step logic
    result = case step do
      {:notify, agent, message} ->
        # Send notification to agent
        MessageBus.publish_message(
          :workflow_engine,
          agent,
          :notification,
          message,
          %{execution_id: execution.id}
        )
        {:ok, execution}

      {:request, agent, request_type, data} ->
        # Send request to agent
        MessageBus.publish_message(
          :workflow_engine,
          agent,
          :request,
          request_type,
          Map.merge(data, %{execution_id: execution.id})
        )
        # Give agent time to process (temporary: should wait for actual response)
        Process.sleep(2000)  # 2 second delay per agent request
        {:ok, execution}

      {:pause, reason} ->
        # Pause for human approval
        paused_exec = %{execution | status: :paused, pause_reason: reason}
        persist_execution(paused_exec)
        {:pause, paused_exec}

      {:decision, _decision_data} ->
        # Record decision in database
        # TODO: Create decision record
        {:ok, execution}

      {:parallel, steps} ->
        # Execute steps in parallel
        Logger.info("Executing #{length(steps)} steps in parallel")
        Enum.each(steps, fn parallel_step ->
          Task.start(fn -> execute_step(parallel_step, execution, nil) end)
        end)
        {:ok, execution}

      {:conditional, condition_fn, true_step, false_step} ->
        # Execute conditional branch
        step_to_execute = if condition_fn.(execution.context), do: true_step, else: false_step
        execute_step(step_to_execute, execution, nil)

      _ ->
        Logger.warning("Unknown step type: #{inspect(step)}")
        {:ok, execution}
    end

    # Persist updated execution state after successful step
    case result do
      {:ok, updated_exec} ->
        next_exec = %{updated_exec | current_step: updated_exec.current_step + 1}
        persist_execution(next_exec)
        {:ok, next_exec}

      {:pause, paused_exec} ->
        {:pause, paused_exec}

      {:error, _} = error ->
        error
    end
  end

  defp update_execution_status(execution_id, status) do
    GenServer.cast(__MODULE__, {:update_status, execution_id, status})
  end

  @impl true
  def handle_cast({:update_status, execution_id, status}, state) do
    case Map.get(state.executions, execution_id) do
      nil ->
        {:noreply, state}

      execution ->
        updated_execution = %{execution |
          status: status,
          completed_at: if(status in [:completed, :failed], do: DateTime.utc_now(), else: nil)
        }

        # Persist status change to database
        persist_execution(updated_execution)

        new_state = put_in(state, [:executions, execution_id], updated_execution)
        {:noreply, new_state}
    end
  end

  ## Private Helper Functions

  defp generate_execution_id do
    "wf_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  # Persist workflow execution to database.
  # Uses upsert to handle both create and update cases.
  defp persist_execution(%Execution{} = execution) do
    attrs = %{
      id: execution.id,
      workflow_name: execution.workflow_name,
      status: execution.status,
      context: execution.context,
      current_step: execution.current_step,
      pause_reason: execution.pause_reason,
      error: if(execution.error, do: inspect(execution.error), else: nil),
      completed_at: execution.completed_at
    }

    %WorkflowExecution{}
    |> WorkflowExecution.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :id
    )
  end

  # Load in-flight workflows from database on startup.
  # Allows resumption of workflows after crash.
  defp load_in_flight_workflows do
    Repo.all(
      from w in WorkflowExecution,
      where: w.status in [:running, :paused]
    )
    |> Enum.map(fn record ->
      execution = WorkflowExecution.to_execution_struct(record)
      {execution.id, execution}
    end)
    |> Map.new()
  end
end
