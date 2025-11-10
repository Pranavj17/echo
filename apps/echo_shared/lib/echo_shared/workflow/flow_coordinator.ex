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

  alias EchoShared.Workflow.FlowEngine
  alias EchoShared.Schemas.FlowExecution
  alias EchoShared.Repo

  @default_timeout 60_000  # 60 seconds
  @max_timeout 600_000     # 10 minutes max - prevents resource exhaustion

  # SECURITY: Whitelist of valid agent roles - prevents atom exhaustion attack
  @valid_agents [:ceo, :cto, :chro, :operations_head, :product_manager,
                 :senior_architect, :uiux_engineer, :senior_developer, :test_lead, :workflow]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register that a flow is waiting for an agent response.

  ## Security
  - Agent must be in whitelist to prevent atom exhaustion
  - Timeout is capped at @max_timeout to prevent resource exhaustion
  """
  def await_response(execution_id, agent, request_id, timeout \\ @default_timeout) do
    # SECURITY: Validate agent is in whitelist
    unless agent in @valid_agents do
      Logger.error("Invalid agent role: #{inspect(agent)}")
      {:error, :invalid_agent}
    else
      # SECURITY: Cap timeout to prevent resource exhaustion
      safe_timeout = min(timeout, @max_timeout)
      GenServer.call(__MODULE__, {:await_response, execution_id, agent, request_id, safe_timeout})
    end
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

  # SECURITY: Parse agent role from string without creating arbitrary atoms
  # Prevents atom exhaustion attack from malicious Redis messages
  defp parse_agent_role(agent_string) when is_binary(agent_string) do
    case agent_string do
      "ceo" -> {:ok, :ceo}
      "cto" -> {:ok, :cto}
      "chro" -> {:ok, :chro}
      "operations_head" -> {:ok, :operations_head}
      "product_manager" -> {:ok, :product_manager}
      "senior_architect" -> {:ok, :senior_architect}
      "uiux_engineer" -> {:ok, :uiux_engineer}
      "senior_developer" -> {:ok, :senior_developer}
      "test_lead" -> {:ok, :test_lead}
      "workflow" -> {:ok, :workflow}
      _ ->
        Logger.warning("Invalid agent role from message: #{agent_string}")
        {:error, :invalid_agent}
    end
  end

  defp parse_agent_role(nil), do: {:error, :missing_agent}
  defp parse_agent_role(_), do: {:error, :invalid_agent_type}

  defp handle_agent_response(message, state) do
    # SECURITY: Extract agent safely without creating arbitrary atoms
    case parse_agent_role(message["from"]) do
      {:ok, agent} ->
        request_id = message["request_id"] || message["in_reply_to"]

        if is_nil(request_id) do
          Logger.warning("Agent response missing request_id, cannot match to flow")
          {:noreply, state}
        else
          handle_valid_agent_response(agent, request_id, message, state)
        end

      {:error, reason} ->
        Logger.warning("Rejecting message from invalid agent: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp handle_valid_agent_response(agent, request_id, message, state) do
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
