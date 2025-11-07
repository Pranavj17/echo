defmodule EchoShared.Schemas.Message do
  @moduledoc """
  Ecto schema for inter-agent messages.

  Tracks all communication between ECHO agents including:
  - Requests for information or action
  - Responses to previous requests
  - Notifications and updates
  - Escalations to higher authority
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "messages" do
    field :from_role, :string
    field :to_role, :string
    field :type, Ecto.Enum, values: [:request, :response, :notification, :escalation]
    field :subject, :string
    field :content, :map
    field :metadata, :map
    field :read, :boolean, default: false
    field :processed_at, :utc_datetime
    field :processing_error, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating a new message.
  """
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:from_role, :to_role, :type, :subject, :content, :metadata, :read, :processed_at, :processing_error])
    |> validate_required([:from_role, :to_role, :type, :subject, :content])
    |> validate_inclusion(:type, [:request, :response, :notification, :escalation])
    |> validate_length(:subject, max: 255)
  end

  @doc """
  Mark message as read/processed.
  """
  def mark_processed(message) do
    change(message, %{
      read: true,
      processed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Mark message processing as failed.
  """
  def mark_failed(message, error) do
    change(message, %{
      read: true,
      processed_at: DateTime.utc_now() |> DateTime.truncate(:second),
      processing_error: inspect(error)
    })
  end
end
