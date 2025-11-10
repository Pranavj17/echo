defmodule EchoShared.Workflow.FlowTest do
  use ExUnit.Case, async: false

  defmodule TestFlow do
    use EchoShared.Workflow.Flow

    @start
    def start_step(state) do
      Map.put(state, :started, true)
    end

    @router :start_step
    def route_decision(state) do
      if Map.get(state, :go_left, false) do
        "left"
      else
        "right"
      end
    end

    @listen "left"
    def handle_left(state) do
      Map.put(state, :direction, :left)
    end

    @listen "right"
    def handle_right(state) do
      Map.put(state, :direction, :right)
    end
  end

  describe "Flow DSL" do
    test "captures start functions" do
      starts = TestFlow.get_starts()
      assert is_list(starts)
      assert length(starts) > 0
    end

    test "captures routers" do
      metadata = TestFlow.__flow_metadata__()
      assert is_map(metadata)
      assert Map.has_key?(metadata, :routers)
    end

    test "captures listeners" do
      listeners = TestFlow.get_listeners("left")
      assert is_list(listeners)
    end

    test "has_router? works" do
      assert TestFlow.has_router?(:start_step)
      refute TestFlow.has_router?(:nonexistent)
    end

    test "execute_step works" do
      state = TestFlow.execute_step(:start_step, %{})
      assert state[:started] == true
    end

    test "route_after works" do
      label = TestFlow.route_after(:start_step, %{go_left: true})
      assert label == "left"

      label = TestFlow.route_after(:start_step, %{go_left: false})
      assert label == "right"
    end
  end
end
