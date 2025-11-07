defmodule EchoShared.MessageBus do
  @moduledoc """
  Redis-based message bus for inter-agent communication.

  Provides real-time pub/sub messaging between ECHO agents using Redis.

  ## Channels

  - `messages:{role}` - Private messages to specific agent
  - `messages:all` - Broadcast to all agents
  - `messages:leadership` - CEO, CTO, CHRO, Ops only
  - `decisions:new` - New decision initiated
  - `decisions:vote_required` - Vote needed from participant
  - `decisions:completed` - Decision finalized
  - `decisions:escalated` - Escalated to higher authority
  - `agents:heartbeat` - Agent health checks
  - `agents:status` - Agent status updates

  ## Usage

  ```elixir
  # Publish a message
  MessageBus.publish_message(:ceo, :cto, :request, "Q3 Strategy Review", %{...})

  # Subscribe to messages
  MessageBus.subscribe_to_role(:ceo)

  # Listen for messages
  MessageBus.listen(fn message ->
    # Handle message
  end)
  ```
  """

  require Logger

  @type role ::
          :ceo
          | :cto
          | :chro
          | :operations_head
          | :product_manager
          | :senior_architect
          | :uiux_engineer
          | :senior_developer
          | :test_lead

  @type message_type :: :request | :response | :notification | :escalation

  @doc """
  Publish a message to a specific agent.

  Uses dual-write pattern:
  1. Persists to database first (durable)
  2. Publishes to Redis (fast notification)

  This ensures messages are never lost even if Redis is unavailable
  or if the recipient agent is down.
  """
  @spec publish_message(role(), role(), message_type(), String.t(), map(), map()) ::
          {:ok, integer()} | {:error, term()}
  def publish_message(from, to, type, subject, content, metadata \\ %{}) do
    # Step 1: Store in database FIRST (durable)
    case store_message_in_db(from, to, type, subject, content) do
      {:ok, db_message} ->
        # Step 2: Publish to Redis for fast notification
        message = %{
          db_id: db_message.id,
          id: generate_message_id(),
          from: to_string(from),
          to: to_string(to),
          type: to_string(type),
          subject: subject,
          content: content,
          metadata: Map.merge(metadata, %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()})
        }

        channel = "messages:#{to}"

        case Jason.encode(message) do
          {:ok, json} ->
            # Best effort: if Redis fails, message is still in DB
            case Redix.command(:redix, ["PUBLISH", channel, json]) do
              {:ok, _} -> {:ok, db_message.id}
              {:error, redis_error} ->
                Logger.warning("Redis publish failed: #{inspect(redis_error)}, message stored in DB")
                {:ok, db_message.id}
            end

          {:error, reason} ->
            {:error, {:encode_error, reason}}
        end

      {:error, reason} ->
        {:error, {:db_error, reason}}
    end
  end

  @doc """
  Broadcast a message to all agents.

  Uses dual-write pattern (like publish_message):
  1. Persists to database first with to_role="all" (durable)
  2. Publishes to Redis (fast notification)
  3. Monitors subscriber count for delivery verification

  This ensures broadcasts are never lost during agent restarts.
  """
  @spec broadcast_message(role(), message_type(), String.t(), map(), map()) ::
          {:ok, integer()} | {:error, term()}
  def broadcast_message(from, type, subject, content, metadata \\ %{}) do
    # Step 1: Store in database FIRST (durable) with to_role = "all"
    case store_message_in_db(from, :all, type, subject, content) do
      {:ok, db_message} ->
        # Step 2: Publish to Redis for fast notification
        message = %{
          db_id: db_message.id,
          id: generate_message_id(),
          from: to_string(from),
          to: "all",
          type: to_string(type),
          subject: subject,
          content: content,
          metadata: Map.merge(metadata, %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()})
        }

        channel = "messages:all"

        case Jason.encode(message) do
          {:ok, json} ->
            # Best effort: if Redis fails, message is still in DB
            case Redix.command(:redix, ["PUBLISH", channel, json]) do
              {:ok, subscriber_count} ->
                if subscriber_count == 0 do
                  Logger.warning("Broadcast sent but no subscribers on #{channel} (message stored in DB)")
                end
                {:ok, db_message.id}

              {:error, redis_error} ->
                Logger.warning("Redis broadcast failed: #{inspect(redis_error)}, message stored in DB")
                {:ok, db_message.id}
            end

          {:error, reason} ->
            {:error, {:encode_error, reason}}
        end

      {:error, reason} ->
        {:error, {:db_error, reason}}
    end
  end

  @doc """
  Subscribe to messages for a specific role.
  """
  @spec subscribe_to_role(role()) :: {:ok, pid()} | {:error, term()}
  def subscribe_to_role(role) do
    channels = [
      "messages:#{role}",
      "messages:all"
    ]

    # Add leadership channel for executive roles
    channels =
      if role in [:ceo, :cto, :chro, :operations_head] do
        ["messages:leadership" | channels]
      else
        channels
      end

    Redix.PubSub.subscribe(:redix_pubsub, channels, self())
  end

  @doc """
  Publish a decision event.
  """
  @spec publish_decision_event(atom(), map()) :: {:ok, integer()} | {:error, term()}
  def publish_decision_event(event_type, decision_data)
      when event_type in [:new, :vote_required, :completed, :escalated] do
    channel = "decisions:#{event_type}"

    event = Map.merge(decision_data, %{
      event: to_string(event_type),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    case Jason.encode(event) do
      {:ok, json} ->
        Redix.command(:redix, ["PUBLISH", channel, json])

      {:error, reason} ->
        {:error, {:encode_error, reason}}
    end
  end

  @doc """
  Publish agent heartbeat.
  """
  @spec publish_heartbeat(role(), map()) :: {:ok, integer()} | {:error, term()}
  def publish_heartbeat(role, status_data \\ %{}) do
    heartbeat = %{
      role: to_string(role),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      status: Map.get(status_data, :status, "running")
    }

    channel = "agents:heartbeat"

    case Jason.encode(heartbeat) do
      {:ok, json} ->
        Redix.command(:redix, ["PUBLISH", channel, json])

      {:error, reason} ->
        {:error, {:encode_error, reason}}
    end
  end

  @doc """
  Store a message in the database for audit trail.
  """
  @spec store_message_in_db(role(), role(), message_type(), String.t(), map()) ::
          {:ok, EchoShared.Schemas.Message.t()} | {:error, Ecto.Changeset.t()}
  def store_message_in_db(from, to, type, subject, content) do
    attrs = %{
      from_role: to_string(from),
      to_role: to_string(to),
      type: type,
      subject: subject,
      content: content,
      metadata: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    }

    %EchoShared.Schemas.Message{}
    |> EchoShared.Schemas.Message.changeset(attrs)
    |> EchoShared.Repo.insert()
  end

  @doc """
  Fetch unread messages for an agent.

  This is called:
  1. On agent startup (to catch up on missed messages)
  2. Periodically as fallback if Redis is down
  3. On reconnect after network partition
  """
  @spec fetch_unread_messages(role()) :: [EchoShared.Schemas.Message.t()]
  def fetch_unread_messages(role) do
    import Ecto.Query

    EchoShared.Repo.all(
      from m in EchoShared.Schemas.Message,
      where: m.to_role == ^to_string(role) and m.read == false,
      order_by: [asc: m.inserted_at]
    )
  end

  @doc """
  Fetch unread broadcast messages (to_role="all").

  Fix #5: Allows agents to catch up on missed broadcasts during startup/restart.
  Called on agent initialization to recover broadcasts missed while offline.
  """
  @spec fetch_unread_broadcasts(role()) :: [EchoShared.Schemas.Message.t()]
  def fetch_unread_broadcasts(_role) do
    import Ecto.Query

    EchoShared.Repo.all(
      from m in EchoShared.Schemas.Message,
      where: m.to_role == "all" and m.read == false,
      order_by: [asc: m.inserted_at],
      limit: 50
    )
  end

  @doc """
  Mark a message as processed.

  Called after an agent successfully handles a message.
  """
  @spec mark_message_processed(integer()) :: {:ok, EchoShared.Schemas.Message.t()} | {:error, term()}
  def mark_message_processed(message_id) do
    case EchoShared.Repo.get(EchoShared.Schemas.Message, message_id) do
      nil ->
        {:error, :not_found}

      message ->
        message
        |> EchoShared.Schemas.Message.mark_processed()
        |> EchoShared.Repo.update()
    end
  end

  @doc """
  Mark a message processing as failed.

  Called when an agent fails to handle a message.
  """
  @spec mark_message_failed(integer(), term()) :: {:ok, EchoShared.Schemas.Message.t()} | {:error, term()}
  def mark_message_failed(message_id, error) do
    case EchoShared.Repo.get(EchoShared.Schemas.Message, message_id) do
      nil ->
        {:error, :not_found}

      message ->
        message
        |> EchoShared.Schemas.Message.mark_failed(error)
        |> EchoShared.Repo.update()
    end
  end

  ## Private Functions

  defp generate_message_id do
    "msg_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
end
