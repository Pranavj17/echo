defmodule Ceo.MessageHandler do
  @moduledoc """
  Handles incoming messages from other agents via Redis pub/sub.

  Subscribes to:
  - messages:ceo (direct messages)
  - messages:all (broadcasts)
  - messages:leadership (C-suite communications)
  - decisions:* (decision events)
  """

  use GenServer
  require Logger

  alias EchoShared.MessageBus
  alias EchoShared.ParticipationEvaluator

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("CEO Message Handler started")

    # Subscribe to CEO messages
    case MessageBus.subscribe_to_role(:ceo) do
      {:ok, ref} ->
        Logger.info("Subscribed to CEO channels via MessageBus (ref: #{inspect(ref)})")
      error ->
        Logger.error("Failed to subscribe to CEO channels: #{inspect(error)}")
    end

    # Subscribe to decision events
    case Redix.PubSub.subscribe(:redix_pubsub, ["decisions:new", "decisions:escalated"], self()) do
      {:ok, ref} ->
        Logger.info("Subscribed to decision events (ref: #{inspect(ref)})")
      error ->
        Logger.error("Failed to subscribe to decision events: #{inspect(error)}")
    end

    {:ok, %{recent_broadcasts: MapSet.new()}}
  end

  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :message, %{channel: channel, payload: payload}}, state) do
    Logger.info("Received Redis message on channel: #{channel}")

    new_state = case Jason.decode(payload) do
      {:ok, message} ->
        handle_message(channel, message, state)

      {:error, reason} ->
        Logger.error("Failed to decode message: #{inspect(reason)}")
        state
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Functions

  defp handle_message("messages:ceo", message, state) do
    Logger.info("CEO received message: #{message["subject"]} from #{message["from"]}")

    case message["type"] do
      "request" -> handle_request(message)
      "escalation" -> handle_escalation(message)
      "notification" -> handle_notification(message)
      _ -> Logger.warning("Unknown message type: #{message["type"]}")
    end

    state
  end

  defp handle_message("messages:all", message, state) do
    Logger.info("CEO received broadcast: #{message["subject"]}")

    message_id = message["id"] || "unknown"

    if MapSet.member?(state.recent_broadcasts, message_id) do
      Logger.debug("CEO already evaluated broadcast #{message_id}, skipping")
      state
    else
      case ParticipationEvaluator.should_participate?(:ceo, message) do
        {:yes, confidence, type} ->
          Logger.info("CEO participating as #{type} (confidence: #{confidence})")
          participate_in_task(message, type)

        {:no, reason} ->
          Logger.debug("CEO declining participation: #{reason}")

        {:defer, _seconds} ->
          Logger.debug("CEO evaluating with LLM (async)...")
      end

      %{state | recent_broadcasts: MapSet.put(state.recent_broadcasts, message_id)}
    end
  end

  defp handle_message("messages:leadership", message, state) do
    Logger.info("CEO received leadership message: #{message["subject"]}")
    # Handle C-suite communications
    state
  end

  defp handle_message("decisions:new", event, state) do
    Logger.info("New decision initiated: #{event["decision_id"]} (#{event["type"]})")
    # CEO can monitor all new decisions
    state
  end

  defp handle_message("decisions:escalated", event, state) do
    Logger.warning("Decision escalated: #{event["decision_id"]}")
    # CEO should review escalated decisions
    handle_escalated_decision(event)
    state
  end

  defp handle_message(_channel, _message, state) do
    # Ignore other channels
    state
  end

  defp handle_request(message) do
    Logger.info("Processing request: #{message["subject"]}")

    # Execute the tool
    tool_name = message["subject"]
    arguments = message["content"] || %{}

    case Ceo.execute_tool(tool_name, arguments) do
      {:ok, result} ->
        Logger.info("Tool #{tool_name} executed successfully")
        send_response(message["from"], message["id"], result)

      {:error, reason} ->
        Logger.error("Tool #{tool_name} failed: #{inspect(reason)}")
        send_error(message["from"], message["id"], reason)
    end
  end

  defp send_response(recipient, request_id, result) do
    response = %{
      "id" => "#{request_id}_response",
      "from" => "ceo",
      "to" => recipient,
      "type" => "response",
      "in_reply_to" => request_id,
      "result" => result,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    channel = "messages:#{recipient}"

    case Redix.command(:redix, ["PUBLISH", channel, Jason.encode!(response)]) do
      {:ok, _} ->
        Logger.info("Sent response to #{recipient} on channel #{channel}")
      {:error, reason} ->
        Logger.error("Failed to send response: #{inspect(reason)}")
    end
  end

  defp send_error(recipient, request_id, reason) do
    error = %{
      "id" => "#{request_id}_error",
      "from" => "ceo",
      "to" => recipient,
      "type" => "error",
      "in_reply_to" => request_id,
      "error" => %{
        "message" => inspect(reason)
      },
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    channel = "messages:#{recipient}"
    {:ok, _} = Redix.command(:redix, ["PUBLISH", channel, Jason.encode!(error)])
    Logger.error("Sent error to #{recipient}")
  end

  defp handle_escalation(message) do
    Logger.warning("Escalation received: #{message["subject"]}")
    # TODO: Handle escalations requiring CEO attention
  end

  defp handle_notification(message) do
    Logger.debug("Notification: #{message["subject"]}")
    # Process informational notifications
  end

  defp handle_escalated_decision(event) do
    # Log escalated decision for CEO review
    Logger.warning("""
    ESCALATED DECISION REQUIRES CEO REVIEW
    Decision ID: #{event["decision_id"]}
    Reason: #{event["reason"]}
    Urgency: #{event["urgency"]}
    """)
  end

  defp participate_in_task(message, participation_type) do
    from = message["from"]
    subject = message["subject"]

    Logger.info("CEO participating in task: #{subject} (as #{participation_type})")

    response_content = case participation_type do
      :lead -> "I'll lead this initiative. My strategic oversight will ensure organizational alignment."
      :assist -> "I can provide strategic guidance on this. Let me know how I can help."
      :observe -> "I'll monitor this initiative to ensure it aligns with our strategic goals."
    end

    MessageBus.publish_message("ceo", from, :response, "Re: #{subject}", %{
      content: response_content,
      participation_type: participation_type,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    MessageBus.store_message_in_db("ceo", from, "response", "Re: #{subject}", %{
      content: response_content,
      participation_type: participation_type
    })

    Logger.info("✓ CEO participation signal sent")
  end
end
