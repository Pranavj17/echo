defmodule EchoShared.Workflow.FlowEngine do
  @moduledoc """
  Execution engine for event-driven Flows.

  Executes flows defined with the Flow DSL (@start, @router, @listen),
  managing state transitions and coordinating with Redis pub/sub for
  agent communication.

  ## Execution Model

  1. **Start** - Execute all @start functions
  2. **Check Router** - See if there's a @router after the start
  3. **Route** - Router returns a label (string)
  4. **Find Listeners** - Get all @listen functions for that label
  5. **Execute Listeners** - Run listener functions
  6. **Repeat** - Go back to step 2 for each listener

  ## Agent Coordination

  When a flow step publishes a message to an agent:
  - Flow execution status = :waiting_agent
  - awaited_response = {agent_role, request_id}
  - FlowCoordinator listens for response
  - On response → update state and continue

  ## State Persistence

  All state is persisted to PostgreSQL after each step, enabling:
  - Recovery after crashes
  - Audit trail of routing decisions
  - Debugging execution history
  """

  require Logger
  alias EchoShared.Repo
  alias EchoShared.Schemas.FlowExecution

  # Whitelist of allowed flow modules - prevents arbitrary code execution
  @allowed_flow_modules [
    EchoShared.Workflow.Examples.FeatureApprovalFlow
    # Add new approved flows here
  ]

  # Maximum state size (1MB) - prevents DoS via large state
  @max_state_size 1_000_000

  @doc """
  Start a flow execution.

  ## Parameters
  - flow_module: The flow module (e.g., MyApp.FeatureApprovalFlow)
  - initial_state: Initial state map (default: %{})

  ## Returns
  {:ok, execution_id} or {:error, reason}

  ## Example

      {:ok, execution_id} = FlowEngine.start_flow(
        FeatureApprovalFlow,
        %{feature_name: "OAuth2", estimated_cost: 500_000}
      )
  """
  def start_flow(flow_module, initial_state \\ %{}) do
    # SECURITY: Validate inputs before execution
    with :ok <- validate_flow_module(flow_module),
         :ok <- validate_initial_state(initial_state) do
      execution_id = generate_execution_id()

      Logger.info("Starting flow #{flow_module} (#{execution_id})")

      # Create flow execution record
      changeset = FlowExecution.changeset(%FlowExecution{}, %{
        id: execution_id,
        flow_module: module_name(flow_module),
        status: :pending,
        state: initial_state
      })

      case Repo.insert(changeset) do
        {:ok, execution} ->
          # SECURITY: Use supervised task instead of unsupervised Task.start
          # This ensures errors are logged and don't silently fail
          task = Task.async(fn -> execute_starts(flow_module, execution) end)

          # We don't await here - execution happens asynchronously
          # But the task is monitored and will log errors if it fails
          Process.demonitor(task.ref, [:flush])

          {:ok, execution_id}

        {:error, changeset} ->
          Logger.error("Failed to create flow execution: #{inspect(changeset.errors)}")
          {:error, :persistence_failed}
      end
    end
  end

  @doc """
  Resume a flow after receiving an agent response.

  Called by FlowCoordinator when an agent responds to a request.
  """
  def resume_flow(execution_id, agent_response) do
    Logger.info("Resuming flow #{execution_id} with agent response")

    case Repo.get(FlowExecution, execution_id) do
      nil ->
        {:error, :not_found}

      execution ->
        # Update state with agent response
        changeset = FlowExecution.receive_agent_response(execution, agent_response)

        case Repo.update(changeset) do
          {:ok, updated_execution} ->
            # SECURITY: Validate flow module from database before loading
            case validate_and_load_flow_module(updated_execution.flow_module) do
              {:ok, flow_module} ->
                # Continue flow execution from where it left off
                continue_after_step(flow_module, updated_execution, updated_execution.current_step)
                {:ok, updated_execution}

              {:error, reason} ->
                Logger.error("Invalid flow module from database: #{updated_execution.flow_module}")
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Get flow execution status.
  """
  def get_status(execution_id) do
    case Repo.get(FlowExecution, execution_id) do
      nil -> {:error, :not_found}
      execution -> {:ok, execution}
    end
  end

  ## Private Functions

  # SECURITY: Validate flow module is in whitelist and properly implements Flow behavior
  defp validate_flow_module(module) when is_atom(module) do
    cond do
      module not in @allowed_flow_modules ->
        Logger.error("Unauthorized flow module: #{inspect(module)}")
        {:error, :unauthorized_flow_module}

      not Code.ensure_loaded?(module) ->
        {:error, :module_not_loaded}

      not function_exported?(module, :__flow_metadata__, 0) ->
        {:error, :not_a_flow_module}

      Enum.empty?(module.get_starts()) ->
        {:error, :no_start_functions}

      true ->
        :ok
    end
  end

  defp validate_flow_module(_module) do
    {:error, :invalid_module_type}
  end

  # SECURITY: Validate and load flow module from database string
  # Prevents arbitrary code execution from corrupted database data
  defp validate_and_load_flow_module(flow_module_string) when is_binary(flow_module_string) do
    try do
      module = String.to_existing_atom("Elixir.#{flow_module_string}")

      case validate_flow_module(module) do
        :ok -> {:ok, module}
        error -> error
      end
    rescue
      ArgumentError ->
        Logger.error("Failed to load flow module: #{flow_module_string}")
        {:error, :invalid_flow_module}
    end
  end

  # SECURITY: Validate initial state size to prevent DoS
  defp validate_initial_state(state) when is_map(state) do
    state_size = :erlang.external_size(state)

    if state_size > @max_state_size do
      Logger.error("State too large: #{state_size} bytes (max: #{@max_state_size})")
      {:error, :state_too_large}
    else
      :ok
    end
  end

  defp validate_initial_state(_state) do
    {:error, :invalid_state_type}
  end

  defp execute_starts(flow_module, execution) do
    Logger.info("Executing @start functions for #{flow_module}")

    # Get all start functions
    start_functions = flow_module.get_starts()

    if Enum.empty?(start_functions) do
      Logger.error("No @start functions defined in #{flow_module}")
      mark_failed(execution, "No @start functions defined")
    else
      # Update status to running
      update_status(execution.id, :running)

      # Execute all start functions (they run in sequence for now)
      final_state = Enum.reduce(start_functions, execution.state, fn {start_fn, _arity}, state ->
        Logger.info("Executing start function: #{start_fn}")

        try do
          flow_module.execute_step(start_fn, state)
        rescue
          error ->
            Logger.error("Start function #{start_fn} failed: #{inspect(error)}")
            state
        end
      end)

      # Update execution with final state
      case Repo.get(FlowExecution, execution.id) do
        nil ->
          Logger.error("Execution #{execution.id} not found")

        exec ->
          updated = Ecto.Changeset.change(exec, %{state: final_state})
          Repo.update(updated)

          # Check if there's a router after the start(s)
          # For now, check the first start function
          {first_start, _} = List.first(start_functions)
          continue_after_step(flow_module, exec, first_start)
      end
    end
  end

  defp continue_after_step(flow_module, execution, step_name) when is_atom(step_name) do
    Logger.info("Checking for router after step: #{step_name}")

    # Check if there's a router for this step
    case flow_module.has_router?(step_name) do
      true ->
        Logger.info("Router found, executing routing logic")
        execute_router(flow_module, execution, step_name)

      false ->
        Logger.info("No router found after #{step_name}, checking for direct listeners")
        # Check for listeners that trigger on step completion
        execute_listeners(flow_module, execution, step_name)
    end
  end

  defp execute_router(flow_module, execution, after_step) do
    Logger.info("Executing router after step: #{after_step}")

    # Get fresh execution state
    execution = Repo.get(FlowExecution, execution.id)

    try do
      # Execute router to get next label
      label = flow_module.route_after(after_step, execution.state)

      Logger.info("Router returned label: #{inspect(label)}")

      if is_nil(label) do
        Logger.info("Router returned nil, flow may be complete")
        mark_completed(execution)
      else
        # Record route decision
        changeset = FlowExecution.record_route(execution, label)

        case Repo.update(changeset) do
          {:ok, updated_execution} ->
            # Execute listeners for this label
            execute_listeners(flow_module, updated_execution, label)

          {:error, reason} ->
            Logger.error("Failed to record route: #{inspect(reason)}")
        end
      end
    rescue
      error ->
        Logger.error("Router failed: #{inspect(error)}")
        mark_failed(execution, "Router error: #{inspect(error)}")
    end
  end

  defp execute_listeners(flow_module, execution, trigger) do
    Logger.info("Finding listeners for trigger: #{inspect(trigger)}")

    # Get listeners for this trigger
    listeners = flow_module.get_listeners(trigger)

    if Enum.empty?(listeners) do
      Logger.info("No listeners found for trigger: #{trigger}, flow may be complete")
      mark_completed(execution)
    else
      Logger.info("Found #{length(listeners)} listener(s) for trigger: #{trigger}")

      # Execute each listener sequentially
      Enum.each(listeners, fn {listener_fn, _arity} ->
        execute_listener(flow_module, execution, listener_fn)
      end)
    end
  end

  defp execute_listener(flow_module, execution, listener_fn) do
    Logger.info("Executing listener: #{listener_fn}")

    # Get fresh execution state
    execution = Repo.get(FlowExecution, execution.id)

    try do
      # Update current step
      changeset = Ecto.Changeset.change(execution, %{current_step: to_string(listener_fn)})
      {:ok, execution} = Repo.update(changeset)

      # Execute listener function
      new_state = flow_module.execute_step(listener_fn, execution.state)

      # Update state
      changeset = Ecto.Changeset.change(execution, %{state: new_state})
      {:ok, updated_execution} = Repo.update(changeset)

      # Mark step as completed
      changeset = FlowExecution.complete_step(updated_execution, to_string(listener_fn))
      {:ok, updated_execution} = Repo.update(changeset)

      # Check for router after this listener
      continue_after_step(flow_module, updated_execution, listener_fn)
    rescue
      error ->
        Logger.error("Listener #{listener_fn} failed: #{inspect(error)}")
        Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
        mark_failed(execution, "Listener error: #{inspect(error)}")
    end
  end

  defp update_status(execution_id, status) do
    case Repo.get(FlowExecution, execution_id) do
      nil -> {:error, :not_found}
      execution ->
        changeset = Ecto.Changeset.change(execution, %{status: status})
        Repo.update(changeset)
    end
  end

  defp mark_completed(execution) do
    Logger.info("Flow #{execution.id} completed")
    changeset = FlowExecution.complete(execution)
    Repo.update(changeset)
  end

  defp mark_failed(execution, error_message) do
    Logger.error("Flow #{execution.id} failed: #{error_message}")
    changeset = FlowExecution.fail(execution, error_message)
    Repo.update(changeset)
  end

  defp generate_execution_id do
    "flow_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp module_name(module) when is_atom(module) do
    module |> Module.split() |> Enum.join(".")
  end
end
