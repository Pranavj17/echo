defmodule EchoShared.Integration.WorkflowTest do
  use ExUnit.Case, async: false

  alias EchoShared.Workflow.{Engine, Definition}

  setup do
    # Start workflow engine for tests
    {:ok, _pid} = Engine.start_link()
    :ok
  end

  describe "simple workflow execution" do
    test "executes sequential steps successfully" do
      workflow = Definition.new(
        "test_sequential",
        "Test sequential workflow",
        [:cto, :senior_architect],
        [
          {:notify, :cto, "Starting workflow"},
          {:notify, :senior_architect, "Step 2"}
        ]
      )

      assert {:ok, workflow} = Definition.validate(workflow)
      assert {:ok, execution_id} = Engine.execute_workflow(workflow)
      assert is_binary(execution_id)

      # Wait briefly for execution
      Process.sleep(100)

      assert {:ok, execution} = Engine.get_status(execution_id)
      assert execution.status in [:running, :completed]
    end
  end

  describe "workflow with pause" do
    test "pauses workflow for human approval" do
      workflow = Definition.new(
        "test_pause",
        "Test workflow with pause",
        [:product_manager],
        [
          {:notify, :product_manager, "Before pause"},
          {:pause, "Need approval"},
          {:notify, :product_manager, "After pause"}
        ]
      )

      assert {:ok, execution_id} = Engine.execute_workflow(workflow)

      # Wait for pause
      Process.sleep(200)

      assert {:ok, execution} = Engine.get_status(execution_id)
      assert execution.status == :paused
      assert execution.pause_reason == "Need approval"

      # Resume workflow
      assert :ok = Engine.resume_workflow(execution_id, %{approved: true})

      # Wait for completion
      Process.sleep(200)

      assert {:ok, execution} = Engine.get_status(execution_id)
      assert execution.status == :completed
    end
  end

  describe "workflow validation" do
    test "validates workflow definition" do
      # Missing name
      invalid_workflow = %Definition{
        name: nil,
        participants: [:cto],
        steps: [{:notify, :cto, "Test"}]
      }

      assert {:error, :missing_name} = Definition.validate(invalid_workflow)

      # Missing participants
      invalid_workflow = %Definition{
        name: "test",
        participants: [],
        steps: [{:notify, :cto, "Test"}]
      }

      assert {:error, :missing_participants} = Definition.validate(invalid_workflow)

      # Valid workflow
      valid_workflow = %Definition{
        name: "test",
        participants: [:cto],
        steps: [{:notify, :cto, "Test"}]
      }

      assert {:ok, ^valid_workflow} = Definition.validate(valid_workflow)
    end
  end
end
