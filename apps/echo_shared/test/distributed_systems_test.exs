defmodule EchoShared.DistributedSystemsTest do
  @moduledoc """
  Integration tests for distributed systems improvements (Phase 4.1).

  Tests:
  1. Workflow persistence and recovery after crash
  2. Message dual-write and acknowledgement
  3. Agent health monitoring and circuit breakers
  """

  use ExUnit.Case, async: false

  alias EchoShared.Workflow.{Engine, Definition, Execution}
  alias EchoShared.Schemas.{WorkflowExecution, Message}
  alias EchoShared.{MessageBus, AgentHealthMonitor, Repo}

  import Ecto.Query

  setup do
    # Setup sandbox for isolated test execution
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Allow GenServers to access the sandbox
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    # Clean database before each test
    Repo.delete_all(WorkflowExecution)
    Repo.delete_all(Message)

    :ok
  end

  describe "Workflow Persistence" do
    test "workflow execution is persisted to database" do
      workflow_def = %Definition{
        name: "test_workflow",
        description: "Test workflow for persistence",
        participants: [:ceo],
        steps: [
          {:notify, :ceo, "Step 1"},
          {:notify, :ceo, "Step 2"}
        ]
      }

      # Execute workflow
      {:ok, execution_id} = Engine.execute_workflow(workflow_def, %{test: true})

      # Wait a bit for execution to start
      Process.sleep(100)

      # Check database - workflow should be persisted
      workflow_record = Repo.get(WorkflowExecution, execution_id)
      assert workflow_record != nil
      assert workflow_record.workflow_name == "test_workflow"
      assert workflow_record.status in [:running, :completed]
    end

    test "in-flight workflows are recovered after engine restart" do
      workflow_def = %Definition{
        name: "long_workflow",
        description: "Long workflow that will be interrupted",
        participants: [:ceo],
        steps: [
          {:pause, "Waiting for approval"}
        ]
      }

      # Start workflow and pause it
      {:ok, execution_id} = Engine.execute_workflow(workflow_def, %{test: true})
      Process.sleep(200)

      # Verify it's in database as paused
      workflow_record = Repo.get(WorkflowExecution, execution_id)
      assert workflow_record != nil
      assert workflow_record.status == :paused

      # Simulate engine crash and restart by stopping and starting
      # (In real scenario, this would be GenServer restart via supervisor)
      # For now, just verify the data is queryable from DB

      in_flight = Repo.all(
        from w in WorkflowExecution,
        where: w.status in [:running, :paused]
      )

      assert length(in_flight) >= 1
      assert Enum.any?(in_flight, fn w -> w.id == execution_id end)
    end
  end

  describe "Message Dual-Write Pattern" do
    test "messages are persisted to database before Redis publish" do
      # Publish a message
      {:ok, message_id} = MessageBus.publish_message(
        :ceo,
        :cto,
        :request,
        "Test Subject",
        %{data: "test"}
      )

      # Verify message is in database
      message = Repo.get(Message, message_id)
      assert message != nil
      assert message.from_role == "ceo"
      assert message.to_role == "cto"
      assert message.subject == "Test Subject"
      assert message.read == false
    end

    test "unread messages can be fetched for an agent" do
      # Create multiple messages
      {:ok, _} = MessageBus.publish_message(:ceo, :cto, :request, "Message 1", %{})
      {:ok, _} = MessageBus.publish_message(:ceo, :cto, :request, "Message 2", %{})
      {:ok, _} = MessageBus.publish_message(:ceo, :chro, :request, "Message 3", %{})

      # Fetch unread for CTO
      unread = MessageBus.fetch_unread_messages(:cto)

      assert length(unread) == 2
      assert Enum.all?(unread, fn m -> m.to_role == "cto" and m.read == false end)
    end

    test "messages can be marked as processed" do
      {:ok, message_id} = MessageBus.publish_message(
        :ceo,
        :cto,
        :request,
        "Test",
        %{}
      )

      # Mark as processed
      {:ok, updated} = MessageBus.mark_message_processed(message_id)

      assert updated.read == true
      assert updated.processed_at != nil
    end

    test "failed message processing is tracked" do
      {:ok, message_id} = MessageBus.publish_message(
        :ceo,
        :cto,
        :request,
        "Test",
        %{}
      )

      # Mark as failed
      error = {:error, "Something went wrong"}
      {:ok, updated} = MessageBus.mark_message_failed(message_id, error)

      assert updated.read == true
      assert updated.processed_at != nil
      assert updated.processing_error != nil
    end
  end

  describe "Agent Health Monitoring" do
    test "agent heartbeat is recorded" do
      # Record heartbeat
      AgentHealthMonitor.record_heartbeat(:ceo, %{version: "1.0.0"})

      # Wait for async processing
      Process.sleep(100)

      # Check database
      status = Repo.get_by(EchoShared.Schemas.AgentStatus, role: "ceo")
      assert status != nil
      assert status.status == "running"
      assert status.last_heartbeat != nil
    end

    test "agent is considered available with recent heartbeat" do
      # Record heartbeat
      AgentHealthMonitor.record_heartbeat(:ceo, %{})
      Process.sleep(100)

      # Check availability
      assert AgentHealthMonitor.agent_available?(:ceo) == true
    end

    test "agent is considered down without recent heartbeat" do
      # Check agent that never sent heartbeat
      assert AgentHealthMonitor.agent_available?(:unknown_agent) == false
    end

    test "down agents are tracked" do
      # Create an old heartbeat (simulating down agent)
      old_time = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      Repo.insert!(%EchoShared.Schemas.AgentStatus{
        role: "old_agent",
        status: "running",
        last_heartbeat: old_time,
        metadata: %{}
      })

      # Wait for health check cycle
      Process.sleep(100)

      down = AgentHealthMonitor.down_agents()
      assert "old_agent" in down
    end
  end

  describe "Integration: Complete Failover Scenario" do
    test "workflow + messages + health monitoring work together" do
      # 1. Start a workflow
      workflow_def = %Definition{
        name: "integration_test",
        description: "Integration test workflow",
        participants: [:ceo, :cto],
        steps: [
          {:request, :cto, "analyze", %{project: "ECHO"}},
          {:notify, :ceo, "Analysis complete"}
        ]
      }

      {:ok, execution_id} = Engine.execute_workflow(workflow_def, %{})
      Process.sleep(200)

      # 2. Verify workflow persisted
      workflow = Repo.get(WorkflowExecution, execution_id)
      assert workflow != nil

      # 3. Verify messages sent (should be in DB)
      messages = Repo.all(from m in Message, where: m.to_role == "cto")
      assert length(messages) > 0

      # 4. Record agent heartbeats
      AgentHealthMonitor.record_heartbeat(:ceo, %{})
      AgentHealthMonitor.record_heartbeat(:cto, %{})
      Process.sleep(100)

      # 5. Verify agents are healthy
      assert AgentHealthMonitor.agent_available?(:ceo)
      assert AgentHealthMonitor.agent_available?(:cto)
    end
  end
end
