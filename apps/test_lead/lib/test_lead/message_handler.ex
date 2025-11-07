defmodule TestLead.MessageHandler do
  @moduledoc """
  Handles incoming messages from other agents via Redis pub/sub.

  Subscribes to:
  - messages:test_lead (direct messages)
  - messages:all (broadcasts)
  - messages:leadership (C-suite communications)
  - decisions:* (decision events from engineering team)
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
    Logger.info("TEST_LEAD Message Handler started")

    # Subscribe to TEST_LEAD messages
    {:ok, _} = MessageBus.subscribe_to_role(:test_lead)

    # Subscribe to decision events
    Redix.PubSub.subscribe(:redix_pubsub, ["decisions:new", "decisions:escalated"], self())

    {:ok, %{recent_broadcasts: MapSet.new()}}
  end

  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :message, %{channel: channel, payload: payload}}, state) do
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

  defp handle_message("messages:test_lead", message, state) do
    Logger.info("TEST_LEAD received message: #{message["subject"]} from #{message["from"]}")

    case message["type"] do
      "request" -> handle_request(message)
      "escalation" -> handle_escalation(message)
      "notification" -> handle_notification(message)
      _ -> Logger.warning("Unknown message type: #{message["type"]}")
    end

    state
  end

  defp handle_message("messages:all", message, state) do
    Logger.info("TEST_LEAD received broadcast: #{message["subject"]}")

    message_id = message["id"] || "unknown"

    if MapSet.member?(state.recent_broadcasts, message_id) do
      Logger.debug("TEST_LEAD already evaluated broadcast #{message_id}, skipping")
      state
    else
      case ParticipationEvaluator.should_participate?(:test_lead, message) do
        {:yes, confidence, type} ->
          Logger.info("TEST_LEAD participating as #{type} (confidence: #{confidence})")
          participate_in_task(message, type)

        {:no, reason} ->
          Logger.debug("TEST_LEAD declining participation: #{reason}")

        {:defer, _seconds} ->
          Logger.debug("TEST_LEAD evaluating with LLM (async)...")
      end

      %{state | recent_broadcasts: MapSet.put(state.recent_broadcasts, message_id)}
    end
  end

  defp handle_message("messages:leadership", message, state) do
    Logger.info("TEST_LEAD received leadership message: #{message["subject"]}")
    # Handle C-suite communications
    state
  end

  defp handle_message("decisions:new", event, state) do
    Logger.info("New decision initiated: #{event["decision_id"]} (#{event["type"]})")
    # TEST_LEAD can monitor technical decisions
    state
  end

  defp handle_message("decisions:escalated", event, state) do
    Logger.warning("Decision escalated: #{event["decision_id"]}")
    # TEST_LEAD should review technical escalations
    handle_escalated_decision(event)
    state
  end

  defp handle_message(_channel, _message, state) do
    # Ignore other channels
    state
  end

  defp handle_request(message) do
    Logger.info("Processing request: #{message["subject"]}")
    # TODO: Process requests based on content
    # For now, just log and acknowledge
  end

  defp handle_escalation(message) do
    Logger.warning("Escalation received: #{message["subject"]}")
    # TODO: Handle escalations requiring TEST_LEAD attention
  end

  defp handle_notification(message) do
    Logger.debug("Notification: #{message["subject"]}")
    # Process informational notifications
  end

  defp handle_escalated_decision(event) do
    # Log escalated decision for TEST_LEAD review
    Logger.warning("""
    ESCALATED DECISION REQUIRES TEST_LEAD REVIEW
    Decision ID: #{event["decision_id"]}
    Reason: #{event["reason"]}
    Urgency: #{event["urgency"]}
    """)
  end

  defp participate_in_task(message, participation_type) do
    from = message["from"]
    subject = message["subject"]

    Logger.info("TEST_LEAD participating in task: #{subject} (as #{participation_type})")

    response_content = case participation_type do
      :lead -> "I'll lead this testing initiative. My QA expertise will ensure quality and coverage."
      :assist -> "I can assist with this. Let me know how I can contribute from a testing perspective."
      :observe -> "I'll monitor this work to ensure proper test coverage and quality standards."
    end

    MessageBus.publish_message("test_lead", from, :response, "Re: #{subject}", %{
      content: response_content,
      participation_type: participation_type,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    MessageBus.store_message_in_db("test_lead", from, "response", "Re: #{subject}", %{
      content: response_content,
      participation_type: participation_type
    })

    Logger.info("✓ TEST_LEAD participation signal sent")
  end
end
