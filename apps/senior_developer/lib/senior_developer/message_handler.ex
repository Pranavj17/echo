defmodule SeniorDeveloper.MessageHandler do
  @moduledoc """
  Handles incoming messages from other agents via Redis pub/sub.

  Subscribes to:
  - messages:senior_developer (direct messages)
  - messages:all (broadcasts)
  - messages:leadership (C-suite communications)
  - decisions:* (decision events from engineering team)
  """

  use GenServer
  require Logger

  alias EchoShared.MessageBus
  alias EchoShared.ParticipationEvaluator
  alias EchoShared.LLM.DecisionHelper

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("SENIOR_DEVELOPER Message Handler started")

    # Subscribe to SENIOR_DEVELOPER messages
    case MessageBus.subscribe_to_role(:senior_developer) do
      {:ok, ref} ->
        Logger.info("✓ Subscribed to messages:senior_developer (ref: #{inspect(ref)})")
      error ->
        Logger.error("✗ Failed to subscribe: #{inspect(error)}")
    end

    # Subscribe to decision events
    case Redix.PubSub.subscribe(:redix_pubsub, ["decisions:new", "decisions:escalated"], self()) do
      {:ok, ref} ->
        Logger.info("✓ Subscribed to decision events (ref: #{inspect(ref)})")
      error ->
        Logger.error("✗ Failed to subscribe to decisions: #{inspect(error)}")
    end

    Logger.info("SENIOR_DEVELOPER Message Handler initialization complete. PID: #{inspect(self())}")
    {:ok, %{recent_broadcasts: MapSet.new()}}
  end

  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :message, %{channel: channel, payload: payload}}, state) do
    Logger.info("SENIOR_DEVELOPER received Redis message on channel: #{channel}")

    new_state = case Jason.decode(payload) do
      {:ok, message} ->
        handle_message(channel, message, state)

      {:error, reason} ->
        Logger.error("Failed to decode message: #{inspect(reason)}")
        state
    end

    {:noreply, new_state}
  end

  # Handle subscription confirmations
  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :subscribed, %{channel: channel}}, state) do
    Logger.info("✓ Subscription confirmed for channel: #{channel}")
    {:noreply, state}
  end

  # Handle unsubscription confirmations
  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :unsubscribed, %{channel: channel}}, state) do
    Logger.info("✓ Unsubscribed from channel: #{channel}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("SENIOR_DEVELOPER received unmatched message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  defp handle_message("messages:senior_developer", message, state) do
    Logger.info("SENIOR_DEVELOPER received message: #{message["subject"]} from #{message["from"]}")

    case message["type"] do
      "request" -> handle_request(message)
      "response" -> handle_response(message)
      "escalation" -> handle_escalation(message)
      "notification" -> handle_notification(message)
      _ -> Logger.warning("Unknown message type: #{message["type"]}")
    end

    state
  end

  defp handle_message("messages:all", message, state) do
    Logger.info("SENIOR_DEVELOPER received broadcast: #{message["subject"]}")

    message_id = message["id"] || "unknown"

    if MapSet.member?(state.recent_broadcasts, message_id) do
      Logger.debug("SENIOR_DEVELOPER already evaluated broadcast #{message_id}, skipping")
      state
    else
      case ParticipationEvaluator.should_participate?(:senior_developer, message) do
        {:yes, confidence, type} ->
          Logger.info("SENIOR_DEVELOPER participating as #{type} (confidence: #{confidence})")
          participate_in_task(message, type)

        {:no, reason} ->
          Logger.debug("SENIOR_DEVELOPER declining participation: #{reason}")

        {:defer, _seconds} ->
          Logger.debug("SENIOR_DEVELOPER evaluating with LLM (async)...")
      end

      %{state | recent_broadcasts: MapSet.put(state.recent_broadcasts, message_id)}
    end
  end

  defp handle_message("messages:leadership", message, state) do
    Logger.info("SENIOR_DEVELOPER received leadership message: #{message["subject"]}")
    # Handle C-suite communications
    state
  end

  defp handle_message("decisions:new", event, state) do
    Logger.info("New decision initiated: #{event["decision_id"]} (#{event["type"]})")
    # SENIOR_DEVELOPER can monitor technical decisions
    state
  end

  defp handle_message("decisions:escalated", event, state) do
    Logger.warning("Decision escalated: #{event["decision_id"]}")
    # SENIOR_DEVELOPER should review technical escalations
    handle_escalated_decision(event)
    state
  end

  defp handle_message(_channel, _message, state) do
    # Ignore other channels
    state
  end

  defp handle_request(message) do
    Logger.info("Processing request: #{message["subject"]}")

    # Use LLM to analyze and respond to the request
    from_agent = message["from"]
    subject = message["subject"]
    content = message["content"]

    # Build context for LLM
    context = %{
      "from_agent" => from_agent,
      "subject" => subject,
      "request_details" => content,
      "my_role" => "Senior Developer",
      "my_capabilities" => ["code implementation", "debugging", "technical design", "code review"]
    }

    question = """
    I received a request from #{from_agent} about: #{subject}

    Request details: #{Jason.encode!(content)}

    As a Senior Developer, how should I respond to this request?
    Consider:
    1. What specific actions can I take?
    2. What information or clarification do I need?
    3. What timeline is reasonable?

    Provide a helpful, professional response.
    """

    Logger.info("Consulting LLM for response to: #{subject}")

    case DecisionHelper.consult(:senior_developer, question, Jason.encode!(context)) do
      {:ok, llm_response} ->
        Logger.info("LLM generated response, sending reply to #{from_agent}")

        # Send response back to the requesting agent
        response_content = %{
          "original_request" => subject,
          "response" => llm_response,
          "status" => "acknowledged",
          "from_llm" => true
        }

        MessageBus.publish_message(
          :senior_developer,
          String.to_atom(from_agent),
          :response,
          "Re: #{subject}",
          response_content
        )

        Logger.info("Response sent to #{from_agent}")

      {:error, reason} ->
        Logger.error("Failed to get LLM response: #{inspect(reason)}")

        # Send fallback response
        fallback_content = %{
          "original_request" => subject,
          "response" => "Request acknowledged. I'll review and get back to you.",
          "status" => "acknowledged",
          "error" => "LLM unavailable"
        }

        MessageBus.publish_message(
          :senior_developer,
          String.to_atom(from_agent),
          :response,
          "Re: #{subject}",
          fallback_content
        )
    end
  end

  defp handle_response(message) do
    Logger.info("Received response: #{message["subject"]} from #{message["from"]}")

    # Log the response content
    content = message["content"]
    Logger.info("Response content: #{inspect(content)}")

    # If the response requires follow-up, the agent can decide to continue the conversation
    # For now, just acknowledge receipt
  end

  defp handle_escalation(message) do
    Logger.warning("Escalation received: #{message["subject"]}")
    # TODO: Handle escalations requiring SENIOR_DEVELOPER attention
  end

  defp handle_notification(message) do
    Logger.debug("Notification: #{message["subject"]}")
    # Process informational notifications
  end

  defp handle_escalated_decision(event) do
    # Log escalated decision for SENIOR_DEVELOPER review
    Logger.warning("""
    ESCALATED DECISION REQUIRES SENIOR_DEVELOPER REVIEW
    Decision ID: #{event["decision_id"]}
    Reason: #{event["reason"]}
    Urgency: #{event["urgency"]}
    """)
  end

  defp participate_in_task(message, participation_type) do
    from = message["from"]
    subject = message["subject"]

    Logger.info("SENIOR_DEVELOPER participating in task: #{subject} (as #{participation_type})")

    response_content = case participation_type do
      :lead -> "I'll lead this development work. My coding expertise will ensure quality implementation."
      :assist -> "I can assist with this. Let me know how I can contribute from a development perspective."
      :observe -> "I'll monitor this work to ensure code quality and best practices."
    end

    MessageBus.publish_message("senior_developer", from, :response, "Re: #{subject}", %{
      content: response_content,
      participation_type: participation_type,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    MessageBus.store_message_in_db("senior_developer", from, "response", "Re: #{subject}", %{
      content: response_content,
      participation_type: participation_type
    })

    Logger.info("✓ SENIOR_DEVELOPER participation signal sent")
  end
end
