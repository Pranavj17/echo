defmodule EchoShared.Workflow.Examples.FeatureApprovalFlow do
  @moduledoc """
  Example Flow: Feature Approval Workflow

  Demonstrates event-driven workflow with conditional routing based on
  feature cost and complexity.

  ## Flow Steps

  1. PM proposes feature → Architect estimates complexity
  2. Router decides approval path based on cost & complexity:
     - High cost (>$1M) → CEO approval required
     - High complexity (>8) → CTO approval required
     - Low risk → Auto-approve
  3. Appropriate approver reviews
  4. All stakeholders notified of decision

  ## Usage

      alias EchoShared.Workflow.FlowEngine
      alias EchoShared.Workflow.Examples.FeatureApprovalFlow

      {:ok, execution_id} = FlowEngine.start_flow(
        FeatureApprovalFlow,
        %{
          feature_name: "User Authentication",
          description: "Implement OAuth2 authentication",
          estimated_cost: 500_000
        }
      )

      # Monitor progress
      {:ok, status} = FlowEngine.get_status(execution_id)
  """

  use EchoShared.Workflow.Flow
  require Logger

  alias EchoShared.MessageBus

  @impl true
  def participants do
    [:product_manager, :senior_architect, :ceo, :cto]
  end

  ## Step 1: Analyze the feature request

  @start
  def analyze_feature_request(state) do
    Logger.info("Analyzing feature request: #{state[:feature_name]}")

    # In a real implementation, this would call the PM agent to refine requirements
    # For now, we'll simulate the analysis

    state
    |> Map.put(:analyzed, true)
    |> Map.put(:timestamp, DateTime.utc_now())
    |> Map.put_new(:complexity, 5)  # Default complexity if not provided
  end

  ## Step 2: Router decides approval path

  @router :analyze_feature_request
  def route_by_risk(state) do
    cost = Map.get(state, :estimated_cost, 0)
    complexity = Map.get(state, :complexity, 0)

    Logger.info("Routing decision: cost=#{cost}, complexity=#{complexity}")

    cond do
      cost > 1_000_000 ->
        Logger.info("High cost detected, routing to CEO")
        "ceo_approval"

      complexity > 8 ->
        Logger.info("High complexity detected, routing to CTO")
        "cto_approval"

      true ->
        Logger.info("Low risk feature, auto-approving")
        "auto_approve"
    end
  end

  ## Step 3a: CEO Approval Path

  @listen "ceo_approval"
  def request_ceo_approval(state) do
    Logger.info("Requesting CEO approval for feature: #{state[:feature_name]}")

    request_id = generate_request_id()

    # Publish request to CEO via Redis
    MessageBus.publish_message(
      :workflow,
      :ceo,
      :request,
      "Approve high-cost feature",
      %{
        feature_name: state[:feature_name],
        description: state[:description],
        estimated_cost: state[:estimated_cost],
        complexity: state[:complexity],
        request_id: request_id,
        requires_response: true
      }
    )

    state
    |> Map.put(:approval_requested_from, :ceo)
    |> Map.put(:approval_request_id, request_id)
  end

  ## Step 3b: CTO Approval Path

  @listen "cto_approval"
  def request_cto_approval(state) do
    Logger.info("Requesting CTO approval for feature: #{state[:feature_name]}")

    request_id = generate_request_id()

    # Publish request to CTO via Redis
    MessageBus.publish_message(
      :workflow,
      :cto,
      :request,
      "Review high-complexity feature",
      %{
        feature_name: state[:feature_name],
        description: state[:description],
        estimated_cost: state[:estimated_cost],
        complexity: state[:complexity],
        request_id: request_id,
        requires_response: true
      }
    )

    state
    |> Map.put(:approval_requested_from, :cto)
    |> Map.put(:approval_request_id, request_id)
  end

  ## Step 3c: Auto-Approve Path

  @listen "auto_approve"
  def auto_approve_feature(state) do
    Logger.info("Auto-approving low-risk feature: #{state[:feature_name]}")

    # Broadcast approval to all stakeholders
    MessageBus.broadcast_message(
      :workflow,
      :notification,
      "Feature auto-approved: #{state[:feature_name]}",
      %{
        feature_name: state[:feature_name],
        estimated_cost: state[:estimated_cost],
        complexity: state[:complexity],
        approval_type: :auto,
        approved_at: DateTime.utc_now()
      }
    )

    state
    |> Map.put(:approved, true)
    |> Map.put(:approval_type, :auto)
    |> Map.put(:approved_at, DateTime.utc_now())
  end

  ## Helper Functions

  defp generate_request_id do
    "req_" <> (:crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower))
  end
end
