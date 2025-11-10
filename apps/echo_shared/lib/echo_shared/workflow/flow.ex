defmodule EchoShared.Workflow.Flow do
  @moduledoc """
  Event-driven workflow DSL inspired by CrewAI Flows.

  Provides declarative macros for defining workflows with:
  - @start - Entry point(s) for workflow execution
  - @router - Conditional routing based on state
  - @listen - Event handlers triggered by router labels or other steps

  ## Example

      defmodule MyFlow do
        use EchoShared.Workflow.Flow

        @start
        def analyze_request(state) do
          state
          |> Map.put(:feature_name, "OAuth2")
          |> Map.put(:estimated_cost, 500_000)
        end

        @router :analyze_request
        def route_by_cost(state) do
          cond do
            state.estimated_cost > 1_000_000 -> "ceo_approval"
            state.complexity > 8 -> "cto_approval"
            true -> "auto_approve"
          end
        end

        @listen "ceo_approval"
        def ceo_reviews(state) do
          # Publish message to CEO via Redis
          MessageBus.publish_message(:workflow, :ceo, :request, "Approve feature", state)
          state
        end

        @listen "cto_approval"
        def cto_reviews(state) do
          MessageBus.publish_message(:workflow, :cto, :request, "Review architecture", state)
          state
        end

        @listen "auto_approve"
        def auto_approve(state) do
          MessageBus.broadcast_message(:workflow, :notification, "Feature auto-approved", state)
          Map.put(state, :approved, true)
        end
      end

  ## State Management

  State is a map that flows through the workflow steps. Each step function receives
  the current state and returns the updated state.

  ## Integration with Redis Pub/Sub

  The Flow DSL integrates with ECHO's Redis pub/sub architecture:
  - Flows publish messages to agents via MessageBus
  - FlowCoordinator listens for agent responses
  - Router decisions are based on agent responses stored in state
  """

  @doc """
  Defines a Flow behavior module.

  When you `use EchoShared.Workflow.Flow`, your module will:
  1. Import the @start, @router, and @listen macros
  2. Automatically register step metadata for the flow engine
  3. Get helper functions for flow execution
  """
  defmacro __using__(_opts) do
    quote do
      import EchoShared.Workflow.Flow

      Module.register_attribute(__MODULE__, :flow_starts, accumulate: true)
      Module.register_attribute(__MODULE__, :flow_routers, accumulate: true)
      Module.register_attribute(__MODULE__, :flow_listeners, accumulate: true)

      @before_compile EchoShared.Workflow.Flow

      @doc """
      Returns list of agents that may participate in this flow.
      """
      def participants do
        []  # Override in flow implementation
      end

      defoverridable participants: 0
    end
  end

  @doc """
  Marks a function as a flow entry point.

  Start functions execute automatically when the flow begins. Multiple start
  functions can be defined and will execute in parallel.

  ## Examples

      @start
      def initialize(state) do
        Map.put(state, :initialized, true)
      end

      @start
      def load_data(state) do
        Map.put(state, :data, fetch_data())
      end
  """
  defmacro start(do: block) do
    quote do
      def unquote(:"__flow_start__")(state) do
        unquote(block)
      end
    end
  end

  @doc """
  Marks a function as a start entry point.

  Place this attribute directly above your start function.

  ## Example

      @start
      def my_start_function(state) do
        # initialization logic
        state
      end
  """
  defmacro start do
    quote do
      @flow_starts {__ENV__.function, __ENV__.module}
    end
  end

  @doc """
  Defines conditional routing logic.

  Router functions are called after a specific step completes and return a
  string label that determines which listener to trigger next.

  ## Example

      @router :analyze_request
      def route_decision(state) do
        if state.cost > 1_000_000 do
          "ceo_approval"
        else
          "auto_approve"
        end
      end
  """
  defmacro router(after_step) do
    quote do
      @flow_routers {__ENV__.function, unquote(after_step)}
    end
  end

  @doc """
  Defines an event listener that executes when triggered.

  Listeners are triggered by:
  - Router returning a matching label (string)
  - Another step completing (atom referencing step name)

  ## Examples

      @listen "ceo_approval"
      def handle_ceo_approval(state) do
        # This runs when router returns "ceo_approval"
        state
      end

      @listen :step_name
      def after_step(state) do
        # This runs after :step_name completes
        state
      end
  """
  defmacro listen(trigger) do
    quote do
      @flow_listeners {__ENV__.function, unquote(trigger)}
    end
  end

  @doc """
  Compile-time validation of flow definition.
  """
  defmacro __before_compile__(env) do
    starts = Module.get_attribute(env.module, :flow_starts)
    routers = Module.get_attribute(env.module, :flow_routers)
    listeners = Module.get_attribute(env.module, :flow_listeners)

    quote do
      @doc """
      Returns flow metadata including all starts, routers, and listeners.
      """
      def __flow_metadata__ do
        %{
          name: __MODULE__ |> Module.split() |> List.last(),
          starts: unquote(Macro.escape(starts)),
          routers: unquote(Macro.escape(routers)),
          listeners: unquote(Macro.escape(listeners))
        }
      end

      @doc """
      Execute a specific step by name.
      """
      def execute_step(step_name, state) when is_atom(step_name) do
        apply(__MODULE__, step_name, [state])
      end

      @doc """
      Check if a router exists after a given step.
      """
      def has_router?(step_name) do
        routers = unquote(Macro.escape(routers))
        Enum.any?(routers, fn {_router_fn, after_step} ->
          after_step == step_name
        end)
      end

      @doc """
      Get router function for a step.
      """
      def get_router(step_name) do
        routers = unquote(Macro.escape(routers))
        case Enum.find(routers, fn {_router_fn, after_step} ->
          after_step == step_name
        end) do
          {router_fn, _} -> router_fn
          nil -> nil
        end
      end

      @doc """
      Execute router after a step.
      """
      def route_after(step_name, state) do
        case get_router(step_name) do
          nil -> nil
          {router_name, _arity} -> apply(__MODULE__, router_name, [state])
        end
      end

      @doc """
      Get listener functions for a trigger (label or step name).
      """
      def get_listeners(trigger) do
        listeners = unquote(Macro.escape(listeners))
        Enum.filter(listeners, fn {_listener_fn, trigger_value} ->
          trigger_value == trigger
        end)
        |> Enum.map(fn {listener_fn, _} -> listener_fn end)
      end

      @doc """
      Get all start functions.
      """
      def get_starts do
        unquote(Macro.escape(starts))
      end
    end
  end
end
