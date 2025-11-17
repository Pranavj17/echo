defmodule Delegator.MessageRouter do
  @moduledoc """
  Routes messages between the delegator and active agents.

  This GenServer subscribes to Redis channels and routes messages
  to/from active agents only, acting as a smart proxy.

  ## Responsibilities

  - Subscribe to delegator's Redis channels
  - Route incoming messages from agents
  - Delegate tasks to agents hierarchically (CEO first)
  - Aggregate responses from multiple agents
  - Handle agent responses and errors

  ## Usage

      # Delegate task to active agents
      MessageRouter.delegate_task(%{
        type: "bug_fix",
        description: "Fix authentication issue",
        context: %{module: "auth", priority: "high"}
      })

      # Send direct message to agent
      MessageRouter.send_to_agent(:ceo, "Please review strategic plan")
  """

  use GenServer
  require Logger
  alias EchoShared.MessageBus
  alias Delegator.AgentRegistry
  alias Delegator.SessionManager

  defstruct [
    :pending_requests,
    :agent_responses,
    :subscribed_channels
  ]

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Delegate a task to active agents.

  If CEO is active, delegates to CEO first (hierarchical).
  Otherwise, broadcasts to all active agents.

  ## Parameters

    * `task` - Map with :type, :description, and optional :context
    * `opts` - Options like :timeout, :require_all_responses

  ## Examples

      MessageRouter.delegate_task(%{
        type: "architecture_review",
        description: "Review microservices design",
        context: %{document_url: "..."}
      })
  """
  @spec delegate_task(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def delegate_task(task, opts \\ []) do
    GenServer.call(__MODULE__, {:delegate_task, task, opts}, 30_000)
  end

  @doc """
  Send a direct message to a specific agent.

  ## Examples

      MessageRouter.send_to_agent(:ceo, "Please approve budget", %{amount: 500_000})
  """
  @spec send_to_agent(atom(), String.t(), map()) :: {:ok, integer()} | {:error, term()}
  def send_to_agent(role, message, context \\ %{}) do
    GenServer.call(__MODULE__, {:send_to_agent, role, message, context})
  end

  @doc """
  Broadcast a message to all active agents.

  ## Examples

      MessageRouter.broadcast_to_agents("Session ending, please save state")
  """
  @spec broadcast_to_agents(String.t(), map()) :: {:ok, integer()}
  def broadcast_to_agents(message, context \\ %{}) do
    GenServer.call(__MODULE__, {:broadcast_to_agents, message, context})
  end

  ## Server Callbacks

  @impl true
  def init(_) do
    # Subscribe to delegator's Redis channels
    :ok = subscribe_to_channels()

    state = %__MODULE__{
      pending_requests: %{},
      agent_responses: %{},
      subscribed_channels: [
        "messages:delegator",
        "messages:all",
        "decisions:completed",
        "decisions:escalated"
      ]
    }

    Logger.info("MessageRouter started and subscribed to channels",
      channels: state.subscribed_channels
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:delegate_task, task, opts}, from, state) do
    active_agents = AgentRegistry.all_agents()

    if Enum.empty?(active_agents) do
      {:reply, {:error, :no_active_agents}, state}
    else
      request_id = generate_request_id()

      # Check if CEO is active (hierarchical delegation)
      ceo_active? = Enum.any?(active_agents, fn {role, _port, _meta} -> role == :ceo end)

      result =
        if ceo_active? do
          delegate_to_ceo(request_id, task, opts)
        else
          delegate_to_all(request_id, task, active_agents, opts)
        end

      # Track pending request
      updated_state = %{
        state
        | pending_requests: Map.put(state.pending_requests, request_id, %{
            from: from,
            task: task,
            started_at: DateTime.utc_now(),
            waiting_for: agent_roles(active_agents)
          })
      }

      case result do
        {:ok, _} ->
          {:reply, {:ok, request_id}, updated_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call({:send_to_agent, role, message, context}, _from, state) do
    unless AgentRegistry.registered?(role) do
      {:reply, {:error, :agent_not_running}, state}
    else
      result =
        MessageBus.publish_message(
          :delegator,
          role,
          :request,
          "Direct task from delegator",
          %{message: message, context: context}
        )

      {:reply, result, state}
    end
  end

  @impl true
  def handle_call({:broadcast_to_agents, message, context}, _from, state) do
    active_agents = AgentRegistry.all_agents()

    results =
      Enum.map(active_agents, fn {role, _port, _meta} ->
        MessageBus.publish_message(
          :delegator,
          role,
          :notification,
          message,
          context
        )
      end)

    success_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)

    {:reply, {:ok, success_count}, state}
  end

  @impl true
  def handle_info({:redis_message, channel, payload}, state) do
    Logger.debug("Received Redis message",
      channel: channel,
      payload: inspect(payload)
    )

    case Jason.decode(payload) do
      {:ok, decoded} ->
        handle_agent_message(channel, decoded, state)

      {:error, reason} ->
        Logger.error("Failed to decode message",
          channel: channel,
          reason: inspect(reason)
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:redix_pubsub, :redix_pubsub, :subscribed, %{channel: channel}}, state) do
    Logger.debug("Subscribed to channel", channel: channel)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Functions

  defp subscribe_to_channels do
    channels = ["messages:delegator", "decisions:completed", "decisions:escalated"]

    case MessageBus.subscribe_to_role(:delegator) do
      {:ok, _pid} ->
        Logger.info("Successfully subscribed to MessageBus channels", channels: channels)
        :ok

      {:error, reason} ->
        Logger.error("Failed to subscribe to channels", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp delegate_to_ceo(request_id, task, _opts) do
    Logger.info("Delegating task to CEO (hierarchical)",
      request_id: request_id,
      task_type: task[:type]
    )

    MessageBus.publish_message(
      :delegator,
      :ceo,
      :request,
      "Task delegation: #{task[:type]}",
      %{
        request_id: request_id,
        task: task,
        delegation_mode: :hierarchical,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    )
  end

  defp delegate_to_all(request_id, task, active_agents, _opts) do
    Logger.info("Broadcasting task to all active agents",
      request_id: request_id,
      task_type: task[:type],
      agent_count: length(active_agents)
    )

    Enum.each(active_agents, fn {role, _port, _meta} ->
      MessageBus.publish_message(
        :delegator,
        role,
        :request,
        "Direct task: #{task[:type]}",
        %{
          request_id: request_id,
          task: task,
          delegation_mode: :direct,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      )
    end)

    {:ok, request_id}
  end

  defp handle_agent_message("messages:delegator", message, state) do
    # Message directed to delegator from an agent
    case message do
      %{"from" => agent_role, "type" => "response", "content" => content} ->
        Logger.info("Received response from agent",
          agent: agent_role,
          content_keys: Map.keys(content)
        )

        # Store response
        request_id = get_in(content, ["request_id"])

        if request_id && Map.has_key?(state.pending_requests, request_id) do
          handle_agent_response(request_id, agent_role, content, state)
        else
          {:noreply, state}
        end

      %{"from" => agent_role, "type" => "error"} = msg ->
        Logger.warning("Received error from agent",
          agent: agent_role,
          message: inspect(msg)
        )

        {:noreply, state}

      _ ->
        Logger.debug("Received other message type", message: inspect(message))
        {:noreply, state}
    end
  end

  defp handle_agent_message("decisions:completed", decision_data, state) do
    Logger.info("Decision completed", decision_id: decision_data["decision_id"])
    # Could forward to Claude Desktop if needed
    {:noreply, state}
  end

  defp handle_agent_message("decisions:escalated", decision_data, state) do
    Logger.info("Decision escalated", decision_id: decision_data["decision_id"])
    # Could notify Claude Desktop about escalation
    {:noreply, state}
  end

  defp handle_agent_message(_channel, _message, state) do
    {:noreply, state}
  end

  defp handle_agent_response(request_id, agent_role, content, state) do
    pending = Map.get(state.pending_requests, request_id)

    # Add this agent's response
    responses = Map.get(state.agent_responses, request_id, %{})
    updated_responses = Map.put(responses, agent_role, content)

    # Check if all agents have responded
    all_responded? =
      Enum.all?(pending.waiting_for, fn role ->
        Map.has_key?(updated_responses, role)
      end)

    if all_responded? do
      # All responses received, reply to caller
      aggregated = aggregate_responses(updated_responses)
      GenServer.reply(pending.from, {:ok, aggregated})

      # Cleanup
      updated_state = %{
        state
        | pending_requests: Map.delete(state.pending_requests, request_id),
          agent_responses: Map.delete(state.agent_responses, request_id)
      }

      {:noreply, updated_state}
    else
      # Still waiting for more responses
      updated_state = %{
        state
        | agent_responses: Map.put(state.agent_responses, request_id, updated_responses)
      }

      {:noreply, updated_state}
    end
  end

  defp aggregate_responses(responses) do
    %{
      responses: responses,
      agent_count: map_size(responses),
      aggregated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp agent_roles(agents) do
    Enum.map(agents, fn {role, _port, _meta} -> role end)
  end

  defp generate_request_id do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "req_#{timestamp}_#{random}"
  end
end
