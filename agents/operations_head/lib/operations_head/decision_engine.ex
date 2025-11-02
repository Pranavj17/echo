defmodule OperationsHead.DecisionEngine do
  @moduledoc """
  Decision engine for the OPERATIONS_HEAD agent.

  Handles autonomous decision-making logic based on:
  - Decision type and context
  - Confidence thresholds
  - Budget limits
  - Technical policies
  """

  use GenServer
  require Logger

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Evaluate if a decision can be made autonomously by the OPERATIONS_HEAD.
  """
  def can_decide_autonomously?(decision_type, context) do
    GenServer.call(__MODULE__, {:can_decide_autonomously, decision_type, context})
  end

  @doc """
  Calculate confidence score for a decision.
  """
  def calculate_confidence(decision_type, context) do
    GenServer.call(__MODULE__, {:calculate_confidence, decision_type, context})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("OPERATIONS_HEAD Decision Engine started")

    state = %{
      decision_authority: Application.get_env(:operations_head, :decision_authority, []),
      escalation_threshold: Application.get_env(:operations_head, :escalation_threshold, 0.7),
      autonomous_mode: Application.get_env(:operations_head, :autonomous_mode, true)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:can_decide_autonomously, decision_type, context}, _from, state) do
    result = evaluate_autonomy(decision_type, context, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:calculate_confidence, decision_type, context}, _from, state) do
    confidence = compute_confidence(decision_type, context, state)
    {:reply, confidence, state}
  end

  ## Private Functions

  defp evaluate_autonomy(decision_type, context, state) do
    cond do
      not state.autonomous_mode ->
        {:cannot_decide, :autonomous_mode_disabled}

      decision_type not in state.decision_authority ->
        {:cannot_decide, :outside_authority}

      not sufficient_context?(context) ->
        {:cannot_decide, :insufficient_context}

      true ->
        confidence = compute_confidence(decision_type, context, state)

        if confidence >= state.escalation_threshold do
          {:can_decide, confidence}
        else
          {:should_escalate, confidence}
        end
    end
  end

  defp compute_confidence(decision_type, context, state) do
    # Base confidence from decision type authority
    base_confidence =
      if decision_type in state.decision_authority do
        0.8
      else
        0.3
      end

    # Adjust based on context completeness
    context_score = context_completeness_score(context)

    # Adjust based on historical success rate (placeholder)
    historical_score = 0.9

    # Combine scores
    confidence = base_confidence * 0.4 + context_score * 0.3 + historical_score * 0.3
    Float.round(confidence, 2)
  end

  defp sufficient_context?(context) when is_map(context) do
    required_keys = [:description, :impact, :stakeholders]
    Enum.all?(required_keys, &Map.has_key?(context, &1))
  end

  defp sufficient_context?(_), do: false

  defp context_completeness_score(context) when is_map(context) do
    total_fields = 10

    fields = [
      :description,
      :impact,
      :stakeholders,
      :budget,
      :timeline,
      :risks,
      :alternatives,
      :dependencies,
      :success_criteria,
      :data
    ]

    present_fields = Enum.count(fields, &Map.has_key?(context, &1))
    Float.round(present_fields / total_fields, 2)
  end

  defp context_completeness_score(_), do: 0.0
end
