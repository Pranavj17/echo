defmodule Delegator do
  @moduledoc """
  Delegator MCP Server - Intelligent agent coordinator for ECHO.

  The Delegator acts as a single entry point to Claude Desktop, spawning
  only the agents needed for a specific task, dramatically reducing
  CPU and memory usage.

  ## Features

  - **Session-based agent management** - Start/end sessions with specific agent sets
  - **Category-based agent selection** - Choose from predefined agent sets
  - **Hierarchical delegation** - CEO coordinates when active
  - **Resource efficiency** - Only load necessary LLMs

  ## MCP Tools

  1. **start_session** - Start new session with agent selection
  2. **list_active_agents** - Show currently running agents
  3. **delegate_task** - Delegate work to active agents
  4. **spawn_agent** - Add specific agent to session
  5. **shutdown_agent** - Remove agent from session
  6. **end_session** - Gracefully shutdown all agents
  7. **session_status** - Get current session details

  ## Usage with Claude Desktop

  Configure in Claude Desktop config:

      {
        "mcpServers": {
          "echo-delegator": {
            "command": "/path/to/echo/apps/delegator/delegator"
          }
        }
      }

  Then use tools from Claude Desktop:

      - start_session(task_category: "development", description: "Fix auth bug")
      - delegate_task(task_type: "bug_fix", description: "Login returns 401")
      - end_session()
  """

  use EchoShared.MCP.Server
  require Logger

  alias Delegator.{AgentSpawner, AgentRegistry, SessionManager, MessageRouter}

  @impl true
  def agent_info do
    %{
      name: "echo-delegator",
      version: "0.1.0",
      role: :delegator,
      description: "Intelligent agent coordinator - spawns only the agents you need"
    }
  end

  @impl true
  def tools do
    [
      %{
        name: "start_session",
        description:
          "Start a new work session with specific agent category. Spawns only the agents needed for that type of work.",
        inputSchema: %{
          type: "object",
          properties: %{
            task_category: %{
              type: "string",
              enum: ["strategic", "technical", "development", "hr", "operations", "product", "quick_fix"],
              description: """
              Task category determines which agents to spawn:
              - strategic: CEO, CTO, Product Manager (big picture decisions)
              - technical: CTO, Senior Architect, Senior Developer (architecture)
              - development: Senior Developer, Test Lead (coding tasks)
              - hr: CEO, CHRO (people management)
              - operations: Operations Head, CTO (infrastructure)
              - product: Product Manager, CEO, UI/UX Engineer (product features)
              - quick_fix: Senior Developer only (simple bug fixes)
              """
            },
            description: %{
              type: "string",
              description: "Brief description of what you want to work on"
            }
          },
          required: ["task_category", "description"]
        }
      },
      %{
        name: "list_active_agents",
        description: "Show which agents are currently running in this session",
        inputSchema: %{
          type: "object",
          properties: %{},
          required: []
        }
      },
      %{
        name: "delegate_task",
        description:
          "Delegate a task to the active agents. If CEO is active, delegates hierarchically. Otherwise broadcasts to all.",
        inputSchema: %{
          type: "object",
          properties: %{
            task_type: %{
              type: "string",
              description: "Type of task (e.g., 'bug_fix', 'architecture_review', 'feature_implementation')"
            },
            description: %{
              type: "string",
              description: "Detailed description of the task"
            },
            context: %{
              type: "object",
              description: "Additional context (optional)",
              properties: %{
                priority: %{type: "string"},
                deadline: %{type: "string"},
                files: %{type: "array", items: %{type: "string"}},
                related_tasks: %{type: "array", items: %{type: "string"}}
              }
            }
          },
          required: ["task_type", "description"]
        }
      },
      %{
        name: "spawn_agent",
        description:
          "Spawn an additional agent during the session (e.g., if you realize you need operations help)",
        inputSchema: %{
          type: "object",
          properties: %{
            role: %{
              type: "string",
              enum: [
                "ceo",
                "cto",
                "chro",
                "operations_head",
                "product_manager",
                "senior_architect",
                "uiux_engineer",
                "senior_developer",
                "test_lead"
              ],
              description: "Agent role to spawn"
            }
          },
          required: ["role"]
        }
      },
      %{
        name: "shutdown_agent",
        description: "Shutdown a specific agent to free resources (e.g., if no longer needed)",
        inputSchema: %{
          type: "object",
          properties: %{
            role: %{
              type: "string",
              description: "Agent role to shutdown"
            }
          },
          required: ["role"]
        }
      },
      %{
        name: "session_status",
        description: "Get current session details: active agents, tasks completed, duration",
        inputSchema: %{
          type: "object",
          properties: %{},
          required: []
        }
      },
      %{
        name: "end_session",
        description: "End the current session and gracefully shutdown all agents",
        inputSchema: %{
          type: "object",
          properties: %{},
          required: []
        }
      }
    ]
  end

  @impl true
  def execute_tool("start_session", %{"task_category" => category_str, "description" => description}) do
    category = String.to_existing_atom(category_str)

    # Check if session already active
    if SessionManager.session_active?() do
      {:ok, "⚠️ Session already active. Use end_session first or continue with current session."}
    else
      # Start session
      case SessionManager.start_session(category, description) do
        {:ok, session} ->
          # Spawn agents for category
          {:ok, spawn_results} = AgentSpawner.spawn_category(category)

          # Count successes
          success_count = Enum.count(spawn_results, fn result -> match?({:ok, _}, result) end)
          error_count = length(spawn_results) - success_count

          agents = AgentSpawner.get_agents_for_category(category)

          result_text = """
          ✓ Session started successfully!

          **Session ID:** #{session.session_id}
          **Category:** #{category}
          **Task:** #{description}

          **Agents spawned:** #{success_count}/#{length(agents)}
          #{format_agent_list(agents)}

          #{if error_count > 0, do: "⚠️ #{error_count} agent(s) failed to spawn\n", else: ""}
          **Status:** Ready to receive tasks
          **Resource usage:** ~#{estimate_memory(agents)}GB memory

          Use `delegate_task` to assign work, or `spawn_agent` to add more agents.
          """

          {:ok, result_text}

        {:error, :already_started} ->
          {:error, "Session already active"}
      end
    end
  end

  @impl true
  def execute_tool("list_active_agents", _args) do
    agents = AgentRegistry.all_agents()

    if Enum.empty?(agents) do
      {:ok, "No agents currently running. Use `start_session` to begin."}
    else
      agent_details =
        Enum.map(agents, fn {role, _port, metadata} ->
          model = Map.get(metadata, :model, "unknown")
          spawned_at = Map.get(metadata, :spawned_at)

          uptime =
            if spawned_at do
              seconds = DateTime.diff(DateTime.utc_now(), spawned_at, :second)
              format_duration(seconds)
            else
              "unknown"
            end

          "- **#{format_role_name(role)}** (#{model}) - Uptime: #{uptime}"
        end)
        |> Enum.join("\n")

      result = """
      **Active Agents:** #{length(agents)}

      #{agent_details}

      **Total estimated memory:** ~#{estimate_memory_for_active()}GB
      """

      {:ok, result}
    end
  end

  @impl true
  def execute_tool("delegate_task", args) do
    task = %{
      type: Map.get(args, "task_type"),
      description: Map.get(args, "description"),
      context: Map.get(args, "context", %{})
    }

    case MessageRouter.delegate_task(task) do
      {:ok, request_id} ->
        active_agents = AgentRegistry.all_agents()
        agent_names = Enum.map(active_agents, fn {role, _, _} -> format_role_name(role) end)

        result = """
        ✓ Task delegated successfully!

        **Request ID:** #{request_id}
        **Task Type:** #{task.type}
        **Delegated to:** #{Enum.join(agent_names, ", ")}

        #{if ceo_active?(), do: "**Mode:** Hierarchical (via CEO)\n", else: "**Mode:** Direct broadcast\n"}
        The agents are now processing your request...
        """

        {:ok, result}

      {:error, :no_active_agents} ->
        {:error, "No agents are currently active. Use `start_session` first."}

      {:error, reason} ->
        {:error, "Failed to delegate task: #{inspect(reason)}"}
    end
  end

  @impl true
  def execute_tool("spawn_agent", %{"role" => role_str}) do
    role = String.to_existing_atom(role_str)

    case AgentSpawner.spawn_agent(role) do
      {:ok, _port} ->
        model = AgentSpawner.get_model(role)

        result = """
        ✓ Agent spawned successfully!

        **Agent:** #{format_role_name(role)}
        **Model:** #{model}
        **Status:** Running

        The agent is now available for task delegation.
        """

        {:ok, result}

      {:error, :already_running} ->
        {:ok, "Agent #{format_role_name(role)} is already running."}

      {:error, {:executable_not_found, path}} ->
        {:error, "Agent executable not found: #{path}\n\nMake sure agents are built: cd apps/#{role} && mix escript.build"}

      {:error, reason} ->
        {:error, "Failed to spawn agent: #{inspect(reason)}"}
    end
  end

  @impl true
  def execute_tool("shutdown_agent", %{"role" => role_str}) do
    role = String.to_existing_atom(role_str)

    case AgentSpawner.shutdown_agent(role) do
      {:ok, :shutdown} ->
        {:ok, "✓ Agent #{format_role_name(role)} shutdown successfully."}

      {:error, :not_running} ->
        {:error, "Agent #{format_role_name(role)} is not currently running."}
    end
  end

  @impl true
  def execute_tool("session_status", _args) do
    case SessionManager.get_session() do
      nil ->
        {:ok, "No active session. Use `start_session` to begin."}

      session ->
        duration = DateTime.diff(DateTime.utc_now(), session.started_at, :second)
        active_agents = AgentRegistry.all_agents()

        agent_list =
          Enum.map(active_agents, fn {role, _, _} -> format_role_name(role) end)
          |> Enum.join(", ")

        result = """
        **Session Status**

        **Session ID:** #{session.session_id}
        **Category:** #{session.task_category}
        **Duration:** #{format_duration(duration)}
        **Started:** #{Calendar.strftime(session.started_at, "%Y-%m-%d %H:%M:%S UTC")}

        **Active Agents:** #{length(active_agents)}
        #{agent_list}

        **Tasks in History:** #{length(session.task_history)}
        **Memory Usage:** ~#{estimate_memory_for_active()}GB

        #{if length(session.task_history) > 0 do
          "**Recent Tasks:**\n" <>
            (session.task_history
             |> Enum.take(3)
             |> Enum.map(&"- #{&1}")
             |> Enum.join("\n"))
        else
          ""
        end}
        """

        {:ok, result}
    end
  end

  @impl true
  def execute_tool("end_session", _args) do
    case SessionManager.end_session() do
      {:ok, summary} ->
        # Shutdown all agents
        {:ok, _results} = AgentSpawner.shutdown_all_agents()

        result = """
        ✓ Session ended successfully!

        **Summary:**
        - Duration: #{format_duration(summary.duration_seconds)}
        - Agents used: #{length(summary.agents_used)}
        - Tasks completed: #{summary.tasks_completed}

        All agents have been shutdown gracefully.
        """

        {:ok, result}

      {:error, :no_session} ->
        {:error, "No active session to end."}
    end
  end

  @impl true
  def execute_tool(tool_name, _args) do
    {:error, "Unknown tool: #{tool_name}"}
  end

  ## Private Helpers

  defp format_agent_list(agents) do
    agents
    |> Enum.map(fn role ->
      model = AgentSpawner.get_model(role)
      "  - #{format_role_name(role)} (#{model})"
    end)
    |> Enum.join("\n")
  end

  defp format_role_name(:ceo), do: "CEO"
  defp format_role_name(:cto), do: "CTO"
  defp format_role_name(:chro), do: "CHRO"
  defp format_role_name(:operations_head), do: "Operations Head"
  defp format_role_name(:product_manager), do: "Product Manager"
  defp format_role_name(:senior_architect), do: "Senior Architect"
  defp format_role_name(:uiux_engineer), do: "UI/UX Engineer"
  defp format_role_name(:senior_developer), do: "Senior Developer"
  defp format_role_name(:test_lead), do: "Test Lead"
  defp format_role_name(role), do: to_string(role) |> String.capitalize()

  defp estimate_memory(agents) do
    # Rough estimates based on model sizes
    memory_map = %{
      ceo: 14,
      cto: 33,
      chro: 8,
      operations_head: 7,
      product_manager: 8,
      senior_architect: 33,
      uiux_engineer: 11,
      senior_developer: 6.7,
      test_lead: 13
    }

    total =
      agents
      |> Enum.map(fn role -> Map.get(memory_map, role, 5) end)
      |> Enum.sum()

    Float.round(total, 1)
  end

  defp estimate_memory_for_active do
    agents = AgentRegistry.all_agents()
    roles = Enum.map(agents, fn {role, _, _} -> role end)
    estimate_memory(roles)
  end

  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}m #{remaining_seconds}s"
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    remaining_seconds = rem(seconds, 3600)
    minutes = div(remaining_seconds, 60)
    "#{hours}h #{minutes}m"
  end

  defp ceo_active? do
    AgentRegistry.registered?(:ceo)
  end
end
