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
      Module.register_attribute(__MODULE__, :flow_starts, accumulate: true)
      Module.register_attribute(__MODULE__, :flow_routers, accumulate: true)
      Module.register_attribute(__MODULE__, :flow_listeners, accumulate: true)
      Module.register_attribute(__MODULE__, :start, accumulate: false)
      Module.register_attribute(__MODULE__, :router, accumulate: false)
      Module.register_attribute(__MODULE__, :listen, accumulate: false)

      @on_definition EchoShared.Workflow.Flow
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

  @doc false
  def __on_definition__(env, kind, name, args, _guards, _body) do
    if kind in [:def, :defp] and length(args) == 1 do
      # Check if @start was set
      if Module.get_attribute(env.module, :start) do
        Module.put_attribute(env.module, :flow_starts, {name, 1})
        Module.delete_attribute(env.module, :start)
      end

      # Check if @router was set
      if after_step = Module.get_attribute(env.module, :router) do
        Module.put_attribute(env.module, :flow_routers, {{name, 1}, after_step})
        Module.delete_attribute(env.module, :router)
      end

      # Check if @listen was set
      if trigger = Module.get_attribute(env.module, :listen) do
        Module.put_attribute(env.module, :flow_listeners, {{name, 1}, trigger})
        Module.delete_attribute(env.module, :listen)
      end
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
