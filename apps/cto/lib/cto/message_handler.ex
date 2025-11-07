defmodule Cto.MessageHandler do
  @moduledoc """
  Handles incoming messages from other agents via Redis pub/sub.

  Subscribes to:
  - messages:cto (direct messages)
  - messages:all (broadcasts)
  - messages:leadership (C-suite communications)
  - decisions:* (decision events from engineering team)
  """

  use GenServer
  require Logger

  alias EchoShared.MessageBus
  alias EchoShared.LLM.Client, as: LLMClient
  alias EchoShared.LLM.Config, as: LLMConfig
  alias EchoShared.ParticipationEvaluator
  alias EchoShared.Repo
  alias EchoShared.Schemas.Memory
  import Ecto.Query

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("CTO Message Handler started")

    # Subscribe to CTO messages
    {:ok, _} = MessageBus.subscribe_to_role(:cto)

    # Subscribe to decision events
    Redix.PubSub.subscribe(:redix_pubsub, ["decisions:new", "decisions:escalated"], self())

    # Initialize state immediately to ensure GenServer starts successfully
    initial_state = %{recent_broadcasts: MapSet.new()}

    # Fix #5: Catch up on missed broadcasts during downtime (with resilient error handling)
    # Use Task to defer database query - don't block initialization
    # If database is unavailable during startup, agent will still start and catch up later
    task = Task.async(fn ->
      try do
        missed_broadcasts = MessageBus.fetch_unread_broadcasts(:cto)
        Logger.info("CTO catching up on #{length(missed_broadcasts)} missed broadcasts")
        missed_broadcasts
      rescue
        error ->
          Logger.warning("CTO couldn't fetch missed broadcasts during init (database may be busy): #{inspect(error)}")
          Logger.info("CTO will process new messages from now on. Missed messages can be caught up later via health check.")
          []
      end
    end)

    # Wait briefly for database query, but don't fail if it times out
    missed_broadcasts = case Task.yield(task, 2000) || Task.shutdown(task) do
      {:ok, broadcasts} -> broadcasts
      nil ->
        Logger.warning("CTO database catchup timed out during init - starting with clean state")
        []
    end

    # Process missed broadcasts with state tracking (only if we got any)
    final_state = Enum.reduce(missed_broadcasts, initial_state, fn msg, acc_state ->
      # Convert DB message to map format expected by handle_message
      message_map = %{
        "id" => to_string(msg.id),
        "from" => msg.from_role,
        "to" => msg.to_role,
        "type" => msg.type,
        "subject" => msg.subject,
        "content" => msg.content
      }

      # P0 Bug Fix #1: Pass state parameter (3-arg version)
      new_state = handle_message("messages:all", message_map, acc_state)

      # P0 Bug Fix #2: Mark message as read after processing (wrap in try/rescue)
      try do
        MessageBus.mark_message_processed(msg.id)
      rescue
        error -> Logger.debug("Couldn't mark message #{msg.id} as processed: #{inspect(error)}")
      end

      new_state
    end)

    # Return final state after catchup (or empty state if catchup failed)
    {:ok, final_state}
  end

  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :message, %{channel: channel, payload: payload}}, state) do
    Logger.info("CTO received Redis message on channel: #{channel}")

    new_state = case Jason.decode(payload) do
      {:ok, message} ->
        updated_state = handle_message(channel, message, state)

        # P1 Fix: Mark Redis messages as processed in DB to prevent re-processing on restart
        # This complements the catchup flow which already marks messages as processed
        if db_id = message["db_id"] do
          case MessageBus.mark_message_processed(db_id) do
            {:ok, _} -> Logger.debug("Marked message #{db_id} as processed")
            {:error, reason} -> Logger.warning("Failed to mark message #{db_id} as processed: #{inspect(reason)}")
          end
        end

        updated_state

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

  # Handle async participation decision from LLM
  @impl true
  def handle_info({:participation_decision, :cto, _message_id, decision}, state) do
    case decision do
      {:yes, confidence, type} ->
        Logger.info("CTO async LLM decision: Participate as #{type} (confidence: #{confidence})")
        # Would participate in task here

      {:no, reason} ->
        Logger.debug("CTO async LLM decision: Decline - #{reason}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("CTO received unmatched message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  # P0 Bug Fix #3: Standardize to accept and return state
  defp handle_message("messages:cto", message, state) do
    Logger.info("CTO received message: #{message["subject"]} from #{message["from"]}")

    case message["type"] do
      "request" -> handle_request(message)
      "escalation" -> handle_escalation(message)
      "notification" -> handle_notification(message)
      _ -> Logger.warning("Unknown message type: #{message["type"]}")
    end

    # Return state unchanged for non-broadcast messages
    state
  end

  defp handle_message("messages:all", message, state) do
    Logger.info("CTO received broadcast: #{message["subject"]}")

    message_id = message["id"] || "unknown"

    # Fix #4: Check if we've already evaluated this broadcast
    if MapSet.member?(state.recent_broadcasts, message_id) do
      Logger.debug("CTO already evaluated broadcast #{message_id}, skipping")
      state
    else
      # Evaluate if CTO should participate
      case ParticipationEvaluator.should_participate?(:cto, message) do
        {:yes, confidence, type} ->
          Logger.info("CTO participating as #{type} (confidence: #{confidence})")
          participate_in_task(message, type)

        {:no, reason} ->
          Logger.debug("CTO declining participation: #{reason}")

        {:defer, _seconds} ->
          Logger.debug("CTO evaluating with LLM (async)...")
          # Async evaluation will send :participation_decision message back
      end

      # Track this message ID to prevent re-evaluation
      %{state | recent_broadcasts: MapSet.put(state.recent_broadcasts, message_id)}
    end
  end

  # P0 Bug Fix #3: Standardize to accept and return state
  defp handle_message("messages:leadership", message, state) do
    Logger.info("CTO received leadership message: #{message["subject"]}")
    # Handle C-suite communications
    state
  end

  # P0 Bug Fix #3: Standardize to accept and return state
  defp handle_message("decisions:new", event, state) do
    Logger.info("New decision initiated: #{event["decision_id"]} (#{event["type"]})")
    # CTO can monitor technical decisions
    state
  end

  # P0 Bug Fix #3: Standardize to accept and return state
  defp handle_message("decisions:escalated", event, state) do
    Logger.warning("Decision escalated: #{event["decision_id"]}")
    # CTO should review technical escalations
    handle_escalated_decision(event)
    state
  end

  # P0 Bug Fix #3: Standardize to accept and return state (catch-all)
  defp handle_message(_channel, _message, state) do
    # Ignore other channels
    state
  end

  defp handle_request(message) do
    Logger.info("Processing request: #{message["subject"]}")
    Logger.info("Message content: #{inspect(message["content"])}")

    # Get relevant memories from database
    memories = get_relevant_memories(message["subject"])

    # Consult LLM for intelligent response
    case consult_llm_for_response(message, memories) do
      {:ok, response_text} ->
        Logger.info("LLM generated response: #{response_text}")
        send_response(message["from"], message["id"], message["subject"], response_text)

      {:error, reason} ->
        Logger.error("LLM consultation failed: #{inspect(reason)}")
        # Send fallback response
        fallback_response = "I received your message about '#{message["subject"]}'. As CTO, I'm reviewing this request and will provide a detailed response shortly."
        send_response(message["from"], message["id"], message["subject"], fallback_response)
    end
  end

  defp get_relevant_memories(subject) do
    # Search memories for relevant technical context
    Repo.all(
      from m in Memory,
      where: fragment("? && ARRAY[?]::varchar[]", m.tags, ["technology", "architecture", "infrastructure"]),
      or_where: ilike(m.content, ^"%#{subject}%"),
      limit: 3
    )
  end

  defp consult_llm_for_response(message, memories) do
    from_role = message["from"] || "unknown"
    subject = message["subject"]
    content = message["content"]

    # Build context from memories
    memory_context = if Enum.empty?(memories) do
      "No relevant organizational memories found."
    else
      memories
      |> Enum.map(fn m -> "- #{m.key}: #{String.slice(m.content, 0..200)}" end)
      |> Enum.join("\n")
    end

    # Create prompt for LLM
    prompt = """
    You are the CTO of the ECHO organization. You just received a message from the #{String.upcase(from_role)}.

    Subject: #{subject}
    Message: #{inspect(content)}

    Relevant organizational context:
    #{memory_context}

    As CTO, you are responsible for:
    - Technology strategy and architecture decisions
    - Engineering excellence and team performance
    - Infrastructure planning and technical standards
    - Engineering budget up to $500,000

    Please provide a thoughtful, technical response that:
    1. Acknowledges the message
    2. Provides your technical perspective
    3. References any relevant organizational context
    4. Suggests concrete next steps if applicable

    Keep your response concise (2-3 paragraphs) and professional.
    """

    Logger.info("Consulting LLM with prompt...")

    # Get model for CTO role
    model = LLMConfig.get_model(:cto)

    # Format prompt as messages list
    messages = [
      %{role: "user", content: prompt}
    ]

    # Call LLM
    case LLMClient.chat(model, messages) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} = error ->
        Logger.error("LLM error: #{inspect(reason)}")
        error
    end
  end

  defp send_response(recipient, request_id, subject, response_text) do
    response = %{
      "id" => "msg_#{:erlang.unique_integer([:positive])}",
      "from" => "cto",
      "to" => recipient,
      "type" => "response",
      "in_reply_to" => request_id,
      "subject" => "Re: #{subject}",
      "content" => response_text,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    channel = "messages:#{recipient}"

    case Redix.command(:redix, ["PUBLISH", channel, Jason.encode!(response)]) do
      {:ok, subscribers} ->
        Logger.info("✓ Sent response to #{recipient} on #{channel} (#{subscribers} subscribers)")
        # Also save to database
        MessageBus.store_message_in_db("cto", recipient, "response", "Re: #{subject}", %{content: response_text})

      {:error, reason} ->
        Logger.error("Failed to send response: #{inspect(reason)}")
    end
  end

  defp handle_escalation(message) do
    Logger.warning("Escalation received: #{message["subject"]}")
    # TODO: Handle escalations requiring CTO attention
  end

  defp handle_notification(message) do
    Logger.debug("Notification: #{message["subject"]}")
    # Process informational notifications
  end

  defp handle_escalated_decision(event) do
    # Log escalated decision for CTO review
    Logger.warning("""
    ESCALATED DECISION REQUIRES CTO REVIEW
    Decision ID: #{event["decision_id"]}
    Reason: #{event["reason"]}
    Urgency: #{event["urgency"]}
    """)
  end

  defp participate_in_task(message, participation_type) do
    # Signal participation intent
    from = message["from"]
    subject = message["subject"]

    Logger.info("CTO participating in task: #{subject} (as #{participation_type})")

    # Send participation signal
    response_content = case participation_type do
      :lead -> "I'll take the lead on this. My technical expertise will ensure proper architecture."
      :assist -> "I can assist with this. Let me know how I can contribute technically."
      :observe -> "I'll monitor this work to ensure alignment with our technical strategy."
    end

    # Use LLM to generate contextual response
    model = LLMConfig.get_model(:cto)
    prompt = """
    You are the CTO participating in this task:

    Subject: #{subject}
    From: #{from}
    Content: #{message["content"]}
    Your role: #{participation_type}

    Write a brief professional response indicating your participation and how you'll contribute.
    Be specific based on the task content.
    """

    messages = [
      %{role: "system", content: "You are the CTO, responsible for technical leadership."},
      %{role: "user", content: prompt}
    ]

    response_text = case LLMClient.chat(model, messages) do
      {:ok, llm_response} ->
        llm_response

      {:error, _reason} ->
        response_content
    end

    # Send response back
    MessageBus.publish_message("cto", from, :response, "Re: #{subject}", %{
      content: response_text,
      participation_type: participation_type,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    # Store in database
    MessageBus.store_message_in_db("cto", from, "response", "Re: #{subject}", %{
      content: response_text,
      participation_type: participation_type
    })

    Logger.info("✓ CTO participation signal sent")
  end
end
