defmodule EchoShared.Workflow.FlowCoordinator do
  @moduledoc """
  Coordinates between Flows and Redis pub/sub for agent communication.

  Responsibilities:
  1. Listen for agent responses on Redis channels
  2. Match responses to waiting flow executions
  3. Resume flows when agents respond
  4. Handle timeouts for agent responses

  ## How It Works

  When a flow publishes a request to an agent:
  ```elixir
  def ceo_reviews(state) do
    request_id = generate_request_id()

    MessageBus.publish_message(
      :workflow,
      :ceo,
      :request,
      "Approve feature",
      Map.put(state, :request_id, request_id)
    )

    # Mark flow as waiting for this specific response
    FlowCoordinator.await_response(execution_id, :ceo, request_id)

    state
  end
  ```

  FlowCoordinator subscribes to all agent channels and:
  1. Receives agent response via Redis
  2. Checks if any flow is waiting for this response
  3. Resumes the flow with the response data

  ## Timeout Handling

  If an agent doesn't respond within a timeout period:
  - Flow can specify fallback behavior
  - Default: mark flow as failed
  - Can escalate to human-in-the-loop
  """

  use GenServer
  require Logger

  alias EchoShared.MessageBus
  alias EchoShared.Workflow.FlowEngine
  alias EchoShared.Schemas.FlowExecution
  alias EchoShared.Repo

  import Ecto.Query

  @default_timeout 60_000  # 60 seconds

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register that a flow is waiting for an agent response.
  """
  def await_response(execution_id, agent, request_id, timeout \\ @default_timeout) do
    GenServer.call(__MODULE__, {:await_response, execution_id, agent, request_id, timeout})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("FlowCoordinator started")

    # Subscribe to all agent response channels
    agent_roles = [:ceo, :cto, :chro, :operations_head, :product_manager,
                   :senior_architect, :uiux_engineer, :senior_developer, :test_lead]

    Enum.each(agent_roles, fn role ->
      channel = "messages:workflow_responses:#{role}"
      case Redix.PubSub.subscribe(:redix_pubsub, channel, self()) do
        {:ok, ref} ->
          Logger.info("Subscribed to #{channel} (ref: #{inspect(ref)})")
        {:error, reason} ->
          Logger.error("Failed to subscribe to #{channel}: #{inspect(reason)}")
      end
    end)

    # Also subscribe to generic workflow channel
    case Redix.PubSub.subscribe(:redix_pubsub, "workflow:agent_responses", self()) do
      {:ok, ref} ->
        Logger.info("Subscribed to workflow:agent_responses (ref: #{inspect(ref)})")
      {:error, reason} ->
        Logger.error("Failed to subscribe: #{inspect(reason)}")
    end

    {:ok, %{waiting: %{}, timeouts: %{}}}
  end

  @impl true
  def handle_call({:await_response, execution_id, agent, request_id, timeout}, _from, state) do
    Logger.info("Flow #{execution_id} awaiting response from #{agent} (request: #{request_id})")

    # Store waiting info
    waiting_key = {agent, request_id}
    new_waiting = Map.put(state.waiting, waiting_key, execution_id)

    # Update execution status in database
    case Repo.get(FlowExecution, execution_id) do
      nil ->
        Logger.error("Flow execution #{execution_id} not found")
        {:reply, {:error, :not_found}, state}

      execution ->
        changeset = FlowExecution.await_agent_response(execution, agent, request_id)

        case Repo.update(changeset) do
          {:ok, _} ->
            # Schedule timeout
            timeout_ref = Process.send_after(self(), {:timeout, execution_id, agent, request_id}, timeout)
            new_timeouts = Map.put(state.timeouts, waiting_key, timeout_ref)

            {:reply, :ok, %{state | waiting: new_waiting, timeouts: new_timeouts}}

          {:error, reason} ->
            Logger.error("Failed to update execution: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :message, %{channel: channel, payload: payload}}, state) do
    Logger.info("Received message on channel: #{channel}")

    case Jason.decode(payload) do
      {:ok, message} ->
        handle_agent_response(message, state)

      {:error, reason} ->
        Logger.error("Failed to decode message: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:timeout, execution_id, agent, request_id}, state) do
    Logger.warning("Flow #{execution_id} timed out waiting for #{agent} response (request: #{request_id})")

    waiting_key = {agent, request_id}

    case Map.get(state.waiting, waiting_key) do
      ^execution_id ->
        # Flow is still waiting, mark as failed
        case Repo.get(FlowExecution, execution_id) do
          nil ->
            Logger.error("Execution #{execution_id} not found")

          execution ->
            changeset = FlowExecution.fail(execution, "Timeout waiting for #{agent} response")
            Repo.update(changeset)
        end

        # Remove from waiting
        new_waiting = Map.delete(state.waiting, waiting_key)
        new_timeouts = Map.delete(state.timeouts, waiting_key)

        {:noreply, %{state | waiting: new_waiting, timeouts: new_timeouts}}

      _ ->
        # Already processed or different execution
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Functions

  defp handle_agent_response(message, state) do
    # Extract agent and request_id from message
    agent = String.to_atom(message["from"] || "unknown")
    request_id = message["request_id"] || message["in_reply_to"]

    if is_nil(request_id) do
      Logger.warning("Agent response missing request_id, cannot match to flow")
      {:noreply, state}
    else
      waiting_key = {agent, request_id}

      case Map.get(state.waiting, waiting_key) do
        nil ->
          Logger.debug("No flow waiting for response from #{agent} (request: #{request_id})")
          {:noreply, state}

        execution_id ->
          Logger.info("Resuming flow #{execution_id} with #{agent} response")

          # Cancel timeout
          case Map.get(state.timeouts, waiting_key) do
            nil -> :ok
            timeout_ref -> Process.cancel_timer(timeout_ref)
          end

          # Resume flow with agent response
          FlowEngine.resume_flow(execution_id, message)

          # Remove from waiting
          new_waiting = Map.delete(state.waiting, waiting_key)
          new_timeouts = Map.delete(state.timeouts, waiting_key)

          {:noreply, %{state | waiting: new_waiting, timeouts: new_timeouts}}
      end
    end
  end
end
