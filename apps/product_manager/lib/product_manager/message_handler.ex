defmodule ProductManager.MessageHandler do
  @moduledoc """
  Handles incoming messages from other agents via Redis pub/sub.

  Subscribes to:
  - messages:product_manager (direct messages)
  - messages:all (broadcasts)
  - messages:leadership (C-suite communications)
  - decisions:* (decision events from engineering team)
  """

  use GenServer
  require Logger

  alias EchoShared.MessageBus
  alias EchoShared.LLM.DecisionHelper
  alias EchoShared.ParticipationEvaluator

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("PRODUCT_MANAGER Message Handler started")

    # Subscribe to PRODUCT_MANAGER messages
    {:ok, _} = MessageBus.subscribe_to_role(:product_manager)

    # Subscribe to decision events
    Redix.PubSub.subscribe(:redix_pubsub, ["decisions:new", "decisions:escalated"], self())

    # Initialize state with recent_broadcasts tracking
    {:ok, %{recent_broadcasts: MapSet.new()}}
  end

  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :message, %{channel: channel, payload: payload}}, state) do
    Logger.info("PRODUCT_MANAGER received Redis message on channel: #{channel}")

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
    Logger.warning("PRODUCT_MANAGER received unmatched message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  defp handle_message("messages:product_manager", message, state) do
    Logger.info("PRODUCT_MANAGER received message: #{message["subject"]} from #{message["from"]}")

    case message["type"] do
      "request" -> handle_request(message)
      "response" -> handle_response(message)
      "escalation" -> handle_escalation(message)
      "notification" -> handle_notification(message)
      _ -> Logger.warning("Unknown message type: #{message["type"]}")
    end

    # Return state unchanged for non-broadcast messages
    state
  end

  defp handle_message("messages:all", message, state) do
    Logger.info("PRODUCT_MANAGER received broadcast: #{message["subject"]}")

    message_id = message["id"] || "unknown"

    # Check if we've already evaluated this broadcast
    if MapSet.member?(state.recent_broadcasts, message_id) do
      Logger.debug("PRODUCT_MANAGER already evaluated broadcast #{message_id}, skipping")
      state
    else
      # Evaluate if Product Manager should participate
      case ParticipationEvaluator.should_participate?(:product_manager, message) do
        {:yes, confidence, type} ->
          Logger.info("PRODUCT_MANAGER participating as #{type} (confidence: #{confidence})")
          participate_in_task(message, type)

        {:no, reason} ->
          Logger.debug("PRODUCT_MANAGER declining participation: #{reason}")

        {:defer, _seconds} ->
          Logger.debug("PRODUCT_MANAGER evaluating with LLM (async)...")
          # Async evaluation will send :participation_decision message back
      end

      # Track this message ID to prevent re-evaluation
      %{state | recent_broadcasts: MapSet.put(state.recent_broadcasts, message_id)}
    end
  end

  defp handle_message("messages:leadership", message, state) do
    Logger.info("PRODUCT_MANAGER received leadership message: #{message["subject"]}")
    # Handle C-suite communications
    state
  end

  defp handle_message("decisions:new", event, state) do
    Logger.info("New decision initiated: #{event["decision_id"]} (#{event["type"]})")
    # PRODUCT_MANAGER can monitor technical decisions
    state
  end

  defp handle_message("decisions:escalated", event, state) do
    Logger.warning("Decision escalated: #{event["decision_id"]}")
    # PRODUCT_MANAGER should review technical escalations
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
      "my_role" => "Product Manager",
      "my_capabilities" => ["product strategy", "requirements definition", "prioritization", "stakeholder management"]
    }

    question = """
    I received a request from #{from_agent} about: #{subject}

    Request details: #{Jason.encode!(content)}

    As a Product Manager, how should I respond to this request?
    Consider:
    1. What product decisions or clarifications are needed?
    2. What requirements or priorities should I specify?
    3. How does this align with product strategy?

    Provide a helpful, professional response.
    """

    Logger.info("Consulting LLM for response to: #{subject}")

    case DecisionHelper.consult(:product_manager, question, Jason.encode!(context)) do
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
          :product_manager,
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
          :product_manager,
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
    # TODO: Handle escalations requiring PRODUCT_MANAGER attention
  end

  defp handle_notification(message) do
    Logger.debug("Notification: #{message["subject"]}")
    # Process informational notifications
  end

  defp handle_escalated_decision(event) do
    # Log escalated decision for PRODUCT_MANAGER review
    Logger.warning("""
    ESCALATED DECISION REQUIRES PRODUCT_MANAGER REVIEW
    Decision ID: #{event["decision_id"]}
    Reason: #{event["reason"]}
    Urgency: #{event["urgency"]}
    """)
  end

  defp participate_in_task(message, participation_type) do
    # Signal participation intent
    from = message["from"]
    subject = message["subject"]

    Logger.info("PRODUCT_MANAGER participating in task: #{subject} (as #{participation_type})")

    # Send participation signal
    response_content = case participation_type do
      :lead -> "I'll take the lead on this. My product expertise will ensure we build the right thing."
      :assist -> "I can assist with this. Let me know how I can contribute from a product perspective."
      :observe -> "I'll monitor this work to ensure alignment with our product strategy."
    end

    # Send response back
    MessageBus.publish_message("product_manager", from, :response, "Re: #{subject}", %{
      content: response_content,
      participation_type: participation_type,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    # Store in database
    MessageBus.store_message_in_db("product_manager", from, "response", "Re: #{subject}", %{
      content: response_content,
      participation_type: participation_type
    })

    Logger.info("✓ PRODUCT_MANAGER participation signal sent")
  end
end
