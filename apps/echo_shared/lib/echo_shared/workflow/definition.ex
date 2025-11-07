defmodule EchoShared.Workflow.Definition do
  @moduledoc """
  Workflow definition structure.

  Defines the steps and participants in a workflow.
  """

  @type step ::
    {:notify, atom(), String.t()}
    | {:request, atom(), String.t(), map()}
    | {:pause, String.t()}
    | {:decision, map()}
    | {:parallel, [step()]}
    | {:conditional, (map() -> boolean()), step(), step()}

  @type t :: %__MODULE__{
    name: String.t(),
    description: String.t(),
    participants: [atom()],
    steps: [step()],
    timeout: integer() | nil,
    metadata: map()
  }

  defstruct [
    :name,
    :description,
    :participants,
    :steps,
    timeout: nil,
    metadata: %{}
  ]

  @doc """
  Create a new workflow definition.
  """
  def new(name, description, participants, steps, opts \\ []) do
    %__MODULE__{
      name: name,
      description: description,
      participants: participants,
      steps: steps,
      timeout: Keyword.get(opts, :timeout),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Validate workflow definition.
  """
  def validate(%__MODULE__{} = workflow) do
    cond do
      is_nil(workflow.name) or workflow.name == "" ->
        {:error, :missing_name}

      is_nil(workflow.participants) or workflow.participants == [] ->
        {:error, :missing_participants}

      is_nil(workflow.steps) or workflow.steps == [] ->
        {:error, :missing_steps}

      true ->
        {:ok, workflow}
    end
  end
end
