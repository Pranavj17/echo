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
  """
  @spec publish_message(role(), role(), message_type(), String.t(), map(), map()) ::
          {:ok, integer()} | {:error, term()}
  def publish_message(from, to, type, subject, content, metadata \\ %{}) do
    message = %{
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
        Redix.command(:redix, ["PUBLISH", channel, json])

      {:error, reason} ->
        {:error, {:encode_error, reason}}
    end
  end

  @doc """
  Broadcast a message to all agents.
  """
  @spec broadcast_message(role(), message_type(), String.t(), map(), map()) ::
          {:ok, integer()} | {:error, term()}
  def broadcast_message(from, type, subject, content, metadata \\ %{}) do
    message = %{
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
        Redix.command(:redix, ["PUBLISH", channel, json])

      {:error, reason} ->
        {:error, {:encode_error, reason}}
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

  ## Private Functions

  defp generate_message_id do
    "msg_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
end
