# Delegator Monitoring Integration Guide

**Date:** 2025-11-12
**Status:** Implementation Ready
**Estimated Time:** 2-3 hours

## Overview

This guide shows how to add real-time Delegator monitoring to the Phoenix LiveView dashboard at `http://localhost:4000`.

### What You'll Add:

✅ New "Delegator" tab in the monitor dashboard
✅ Real-time active session display
✅ Spawned agents list with resource usage
✅ Session history and statistics
✅ Live agent spawn/shutdown events

---

## Part 1: Database Schema (Already Created ✅)

Migration created: `20251111190002_create_delegator_sessions.exs`

Run the migration:
```bash
cd apps/echo_shared
mix ecto.migrate
```

This creates the `delegator_sessions` table with:
- `session_id` - Unique session identifier
- `task_category` - Agent category (quick_fix, development, etc.)
- `active_agents` - Array of spawned agent roles
- `started_at/ended_at` - Session lifecycle
- `total_agents_spawned` - Count of agents used
- `status` - active/completed/error

---

## Part 2: Update Delegator Session Manager

Add database persistence to `apps/delegator/lib/delegator/session_manager.ex`:

###Changes to SessionManager:

```elixir
# At the top, add alias
alias EchoShared.Repo
alias EchoShared.Schemas.DelegatorSession  # We'll create this schema

# In handle_call({:start_session, ...})
# After creating the session struct, also persist to DB:

{:ok, db_session} = %DelegatorSession{}
|> DelegatorSession.changeset(%{
  session_id: session.session_id,
  task_category: to_string(category),
  task_description: description,
  active_agents: [],
  started_at: session.started_at,
  status: "active"
})
|> Repo.insert()

# In handle_call(:end_session, ...)
# Update the database record:

case Repo.get_by(DelegatorSession, session_id: session.session_id) do
  nil -> :ok
  db_session ->
    db_session
    |> DelegatorSession.changeset(%{
      ended_at: DateTime.utc_now(),
      status: "completed",
      active_agents: session.active_agents
    })
    |> Repo.update()
end

# In handle_call({:agent_spawned, role}, ...)
# Update active_agents in database:

case Repo.get_by(DelegatorSession, session_id: session.session_id) do
  nil -> :ok
  db_session ->
    db_session
    |> DelegatorSession.changeset(%{
      active_agents: updated.active_agents,
      total_agents_spawned: length(updated.active_agents)
    })
    |> Repo.update()
end
```

---

## Part 3: Create DelegatorSession Schema

Create `apps/echo_shared/lib/echo_shared/schemas/delegator_session.ex`:

```elixir
defmodule EchoShared.Schemas.DelegatorSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "delegator_sessions" do
    field :session_id, :string
    field :task_category, :string
    field :task_description, :string
    field :active_agents, {:array, :string}, default: []
    field :context, :map, default: %{}
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :total_agents_spawned, :integer, default: 0
    field :tasks_delegated, :integer, default: 0
    field :status, :string, default: "active"

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_id,
      :task_category,
      :task_description,
      :active_agents,
      :context,
      :started_at,
      :ended_at,
      :total_agents_spawned,
      :tasks_delegated,
      :status
    ])
    |> validate_required([:session_id, :task_category, :started_at])
    |> validate_inclusion(:task_category, [
      "strategic",
      "technical",
      "development",
      "hr",
      "operations",
      "product",
      "quick_fix"
    ])
    |> validate_inclusion(:status, ["active", "completed", "error"])
    |> unique_constraint(:session_id)
  end
end
```

---

## Part 4: Add Delegator Analytics Module

Create `monitor/lib/echo_monitor/delegator_analytics.ex`:

```elixir
defmodule EchoMonitor.DelegatorAnalytics do
  @moduledoc """
  Analytics queries for delegator monitoring
  """

  import Ecto.Query
  alias EchoShared.Repo
  alias EchoShared.Schemas.DelegatorSession
  alias Delegator.AgentRegistry

  @doc """
  Get active delegator sessions
  """
  def get_active_sessions do
    DelegatorSession
    |> where([s], s.status == "active")
    |> order_by([s], desc: s.started_at)
    |> Repo.all()
  end

  @doc """
  Get session history for a date
  """
  def get_session_history(date) do
    start_datetime = DateTime.new!(date, ~T[00:00:00])
    end_datetime = DateTime.new!(date, ~T[23:59:59])

    DelegatorSession
    |> where([s], s.started_at >= ^start_datetime and s.started_at <= ^end_datetime)
    |> order_by([s], desc: s.started_at)
    |> limit(50)
    |> Repo.all()
  end

  @doc """
  Get delegator statistics for a date range
  """
  def get_delegator_stats(from_date, to_date \\ nil) do
    to_date = to_date || from_date
    start_datetime = DateTime.new!(from_date, ~T[00:00:00])
    end_datetime = DateTime.new!(to_date, ~T[23:59:59])

    query =
      from s in DelegatorSession,
        where: s.started_at >= ^start_datetime and s.started_at <= ^end_datetime,
        select: %{
          total_sessions: count(s.id),
          avg_agents_per_session: avg(s.total_agents_spawned),
          total_agents_spawned: sum(s.total_agents_spawned),
          category_breakdown:
            fragment(
              "json_object_agg(?, count(*))",
              s.task_category,
              s.id
            )
        }

    Repo.one(query) || %{
      total_sessions: 0,
      avg_agents_per_session: 0.0,
      total_agents_spawned: 0,
      category_breakdown: %{}
    }
  end

  @doc """
  Get currently spawned agents from AgentRegistry
  """
  def get_spawned_agents do
    try do
      agents = AgentRegistry.all_agents()

      Enum.map(agents, fn {role, _port, metadata} ->
        %{
          role: role,
          model: Map.get(metadata, :model, "unknown"),
          spawned_at: Map.get(metadata, :spawned_at),
          uptime_seconds: calculate_uptime(Map.get(metadata, :spawned_at)),
          memory_gb: estimate_memory(role)
        }
      end)
    rescue
      _ -> []
    end
  end

  @doc """
  Get resource usage summary
  """
  def get_resource_summary do
    agents = get_spawned_agents()

    %{
      active_agents: length(agents),
      total_memory_gb: Enum.sum(Enum.map(agents, & &1.memory_gb)),
      cpu_load: estimate_cpu_load(length(agents))
    }
  end

  ## Private Helpers

  defp calculate_uptime(nil), do: 0

  defp calculate_uptime(spawned_at) do
    DateTime.diff(DateTime.utc_now(), spawned_at, :second)
  end

  defp estimate_memory(role) do
    memory_map = %{
      ceo: 14.0,
      cto: 33.0,
      chro: 8.0,
      operations_head: 7.0,
      product_manager: 8.0,
      senior_architect: 33.0,
      uiux_engineer: 11.0,
      senior_developer: 6.7,
      test_lead: 13.0
    }

    Map.get(memory_map, role, 5.0)
  end

  defp estimate_cpu_load(agent_count) do
    cond do
      agent_count == 0 -> "idle"
      agent_count <= 2 -> "low"
      agent_count <= 5 -> "medium"
      true -> "high"
    end
  end
end
```

---

## Part 5: Update Monitor Dashboard

Add delegator tab to `monitor/lib/echo_monitor_web/live/dashboard_live.ex`:

### 5.1 Update mount/3 to load delegator data:

```elixir
defp load_data(socket) do
  date = socket.assigns.selected_date

  socket
  |> assign(:daily_activity, Analytics.get_daily_activity(date))
  |> assign(:performance_metrics, Analytics.get_performance_metrics(date))
  |> assign(:delegation_chain, Analytics.get_delegation_chain(date))
  |> assign(:escalation_stats, Analytics.get_escalation_stats(date))
  |> assign(:activity_timeline, Analytics.get_activity_timeline(24))
  # ADD THESE LINES:
  |> assign(:active_sessions, DelegatorAnalytics.get_active_sessions())
  |> assign(:session_history, DelegatorAnalytics.get_session_history(date))
  |> assign(:spawned_agents, DelegatorAnalytics.get_spawned_agents())
  |> assign(:resource_summary, DelegatorAnalytics.get_resource_summary())
  |> assign(:delegator_stats, DelegatorAnalytics.get_delegator_stats(date))
  |> assign(:last_updated, DateTime.utc_now())
end
```

### 5.2 Add delegator tab button (after line 155):

```elixir
<button
  phx-click="change_view"
  phx-value-view="delegator"
  class={[
    "whitespace-nowrap pb-4 px-1 border-b-2 font-semibold text-sm transition-colors",
    if(@view_mode == :delegator,
      do: "border-white text-white",
      else: "border-transparent text-gray-500 hover:text-gray-300 hover:border-gray-600"
    )
  ]}
>
  Delegator
</button>
```

### 5.3 Add delegator view case (after line 175):

```elixir
<% :delegator -> %>
  <.delegator_view
    active_sessions={@active_sessions}
    session_history={@session_history}
    spawned_agents={@spawned_agents}
    resource_summary={@resource_summary}
    delegator_stats={@delegator_stats}
  />
```

### 5.4 Add delegator view component (after line 547):

```elixir
# Delegator View Component
attr :active_sessions, :list, required: true
attr :session_history, :list, required: true
attr :spawned_agents, :list, required: true
attr :resource_summary, :map, required: true
attr :delegator_stats, :map, required: true

defp delegator_view(assigns) do
  ~H"""
  <div class="space-y-8">
    <!-- Resource Summary Cards -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div class="bg-gray-900 border border-gray-800 rounded-xl shadow-2xl p-8 hover:border-gray-700 transition-all">
        <h3 class="text-sm font-semibold text-gray-400 uppercase tracking-wider">
          Active Agents
        </h3>
        <p class="mt-4 text-5xl font-bold text-white">
          <%= @resource_summary.active_agents %>
        </p>
        <p class="mt-2 text-sm text-gray-500">
          CPU: <span class={cpu_load_color(@resource_summary.cpu_load)}>
            <%= @resource_summary.cpu_load %>
          </span>
        </p>
      </div>

      <div class="bg-gray-900 border border-gray-800 rounded-xl shadow-2xl p-8 hover:border-gray-700 transition-all">
        <h3 class="text-sm font-semibold text-gray-400 uppercase tracking-wider">
          Memory Usage
        </h3>
        <p class="mt-4 text-5xl font-bold text-white">
          <%= Float.round(@resource_summary.total_memory_gb, 1) %><span class="text-3xl text-gray-400">GB</span>
        </p>
        <p class="mt-2 text-sm text-gray-500">
          <%= memory_savings_text(@resource_summary.total_memory_gb) %>
        </p>
      </div>

      <div class="bg-gray-900 border border-gray-800 rounded-xl shadow-2xl p-8 hover:border-gray-700 transition-all">
        <h3 class="text-sm font-semibold text-gray-400 uppercase tracking-wider">
          Active Sessions
        </h3>
        <p class="mt-4 text-5xl font-bold text-white">
          <%= length(@active_sessions) %>
        </p>
        <p class="mt-2 text-sm text-gray-500">
          Total today: <%= @delegator_stats.total_sessions %>
        </p>
      </div>
    </div>

    <!-- Active Sessions -->
    <%= if not Enum.empty?(@active_sessions) do %>
      <div class="bg-gray-900 border border-gray-800 rounded-xl shadow-2xl overflow-hidden">
        <div class="px-6 py-5 border-b border-gray-800">
          <h2 class="text-xl font-bold text-white">Active Sessions</h2>
          <p class="text-sm text-gray-400 mt-2">
            Currently running delegator sessions
          </p>
        </div>
        <div class="p-6 space-y-4">
          <%= for session <- @active_sessions do %>
            <div class="border border-gray-800 rounded-lg p-5 hover:bg-gray-800 transition-all">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center space-x-3">
                    <span class="px-3 py-1 text-xs font-bold rounded-md uppercase tracking-wider bg-white text-black">
                      <%= session.task_category %>
                    </span>
                    <span class="text-sm text-gray-500 font-mono">
                      <%= Calendar.strftime(session.started_at, "%H:%M:%S") %>
                    </span>
                    <span class="text-sm text-gray-400">
                      Duration: <%= format_duration(DateTime.diff(DateTime.utc_now(), session.started_at, :second)) %>
                    </span>
                  </div>
                  <h3 class="mt-3 text-base font-semibold text-white">
                    <%= session.task_description || "No description" %>
                  </h3>
                  <p class="mt-2 text-sm text-gray-400">
                    Session ID: <span class="font-mono text-white"><%= session.session_id %></span>
                  </p>
                  <%= if session.active_agents && length(session.active_agents) > 0 do %>
                    <div class="mt-3 flex flex-wrap gap-2">
                      <%= for agent <- session.active_agents do %>
                        <span class="px-2 py-1 text-xs font-medium bg-gray-800 text-white rounded border border-gray-700">
                          <%= format_role(agent) %>
                        </span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <!-- Spawned Agents -->
    <div class="bg-gray-900 border border-gray-800 rounded-xl shadow-2xl overflow-hidden">
      <div class="px-6 py-5 border-b border-gray-800">
        <h2 class="text-xl font-bold text-white">Spawned Agents</h2>
        <p class="text-sm text-gray-400 mt-2">
          Agents currently running in memory
        </p>
      </div>
      <%= if Enum.empty?(@spawned_agents) do %>
        <div class="p-12 text-center">
          <p class="text-gray-500 text-lg">No agents currently spawned</p>
          <p class="text-gray-600 text-sm mt-2">
            Start a delegator session in Claude Desktop to spawn agents
          </p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-800">
            <thead class="bg-black">
              <tr>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Agent
                </th>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Model
                </th>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Memory
                </th>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Uptime
                </th>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Spawned At
                </th>
              </tr>
            </thead>
            <tbody class="bg-gray-900 divide-y divide-gray-800">
              <%= for agent <- @spawned_agents do %>
                <tr class="hover:bg-gray-800 transition-colors">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex items-center">
                      <div class="flex-shrink-0 h-10 w-10 bg-white rounded-lg flex items-center justify-center">
                        <span class="text-black font-bold text-xs">
                          <%= agent.role |> to_string() |> String.slice(0..1) |> String.upcase() %>
                        </span>
                      </div>
                      <div class="ml-4">
                        <div class="text-sm font-semibold text-white">
                          <%= format_role(agent.role) %>
                        </div>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300 font-mono">
                    <%= agent.model %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-semibold text-white">
                    ~<%= agent.memory_gb %>GB
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                    <%= format_duration(agent.uptime_seconds) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-400 font-mono">
                    <%= if agent.spawned_at do %>
                      <%= Calendar.strftime(agent.spawned_at, "%H:%M:%S") %>
                    <% else %>
                      N/A
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>

    <!-- Session History -->
    <div class="bg-gray-900 border border-gray-800 rounded-xl shadow-2xl overflow-hidden">
      <div class="px-6 py-5 border-b border-gray-800">
        <h2 class="text-xl font-bold text-white">Session History</h2>
        <p class="text-sm text-gray-400 mt-2">
          Recent delegator sessions
        </p>
      </div>
      <%= if Enum.empty?(@session_history) do %>
        <div class="p-12 text-center">
          <p class="text-gray-500 text-lg">No sessions for this date</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-800">
            <thead class="bg-black">
              <tr>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Category
                </th>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Description
                </th>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Agents
                </th>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Duration
                </th>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Status
                </th>
                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-400 uppercase">
                  Started
                </th>
              </tr>
            </thead>
            <tbody class="bg-gray-900 divide-y divide-gray-800">
              <%= for session <- @session_history do %>
                <tr class="hover:bg-gray-800 transition-colors">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="px-2 py-1 text-xs font-bold rounded-md uppercase bg-gray-800 text-white">
                      <%= session.task_category %>
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-300">
                    <%= session.task_description || "N/A" %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-semibold text-white">
                    <%= session.total_agents_spawned %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                    <%= if session.ended_at do %>
                      <%= format_duration(DateTime.diff(session.ended_at, session.started_at, :second)) %>
                    <% else %>
                      Active
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={[
                      "px-2 py-1 text-xs font-bold rounded-md uppercase",
                      session_status_color(session.status)
                    ]}>
                      <%= session.status %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-400 font-mono">
                    <%= Calendar.strftime(session.started_at, "%H:%M:%S") %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
  </div>
  """
end

# Helper functions for delegator view
defp cpu_load_color("idle"), do: "text-gray-500"
defp cpu_load_color("low"), do: "text-white"
defp cpu_load_color("medium"), do: "text-gray-300"
defp cpu_load_color("high"), do: "text-gray-400"

defp memory_savings_text(memory_gb) when memory_gb < 10 do
  "86% savings vs all agents"
end

defp memory_savings_text(memory_gb) when memory_gb < 25 do
  "60% savings vs all agents"
end

defp memory_savings_text(_) do
  "Running multiple agents"
end

defp session_status_color("active"), do: "bg-white text-black"
defp session_status_color("completed"), do: "bg-gray-700 text-white"
defp session_status_color("error"), do: "bg-gray-800 text-white"
defp session_status_color(_), do: "bg-gray-600 text-white"

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
```

---

## Part 6: Test the Integration

### 6.1 Run database migration:
```bash
cd apps/echo_shared
mix ecto.migrate
```

### 6.2 Start the monitor:
```bash
cd monitor
./start.sh
```

### 6.3 Open browser:
```
http://localhost:4000
```

### 6.4 Click the "Delegator" tab

You should see:
- Resource summary cards (active agents, memory, sessions)
- Active sessions section (empty initially)
- Spawned agents table (empty initially)
- Session history (empty initially)

### 6.5 Test with actual session:

In Claude Desktop (with delegator configured):
```
1. start_session(task_category: "quick_fix", description: "Test monitoring")
2. Check monitor dashboard - should show:
   - Active agents: 1
   - Memory usage: ~6.7GB
   - Active session with "quick_fix" category
   - Senior Developer in spawned agents table
3. end_session()
4. Refresh dashboard - session moves to history
```

---

## What the Monitor Will Show

### Real-Time Updates (every 5 seconds):

1. **Resource Summary**
   - Number of active agents
   - Total memory usage with savings percentage
   - Active session count

2. **Active Sessions**
   - Session ID and category
   - Task description
   - Duration (updating live)
   - List of spawned agents

3. **Spawned Agents Table**
   - Agent name and role
   - LLM model being used
   - Memory estimate
   - Uptime
   - Spawn timestamp

4. **Session History**
   - Past sessions for selected date
   - Category, duration, agents used
   - Status (completed/error)
   - Start time

---

## Screenshots (What It Will Look Like)

### Delegator Tab - Active Session:
```
┌─────────────────────────────────────────────────────────┐
│  Active Agents        Memory Usage        Active Sessions│
│      2                   ~20GB                  1         │
│  CPU: medium        60% savings vs all    Total today: 3 │
└─────────────────────────────────────────────────────────┘

Active Sessions
┌─────────────────────────────────────────────────────────┐
│ [DEVELOPMENT] 14:23:05  Duration: 5m 23s                │
│ Implement password reset feature                        │
│ Session ID: session_1731355385_a1b2c3d4                │
│ [Senior Developer] [Test Lead]                          │
└─────────────────────────────────────────────────────────┘

Spawned Agents
┌──────────────────────────────────────────────────────────┐
│ Agent           Model              Memory  Uptime  Time  │
│ Senior Developer deepseek-coder:6.7b ~6.7GB  5m 23s 14:23│
│ Test Lead        codellama:13b     ~13GB    5m 10s 14:23│
└──────────────────────────────────────────────────────────┘
```

---

## Benefits

✅ **Real-time visibility** - See exactly which agents are running
✅ **Resource tracking** - Monitor memory/CPU usage live
✅ **Session history** - Analyze past delegator usage
✅ **Performance insights** - Understand agent usage patterns
✅ **Cost awareness** - See resource savings vs running all agents

---

## Next Steps

After implementing:

1. Add alerting for high resource usage
2. Add session analytics (avg duration, most used categories)
3. Add agent spawn/shutdown event stream
4. Add interactive controls (kill agent, end session)
5. Add graphs for resource usage over time

---

**Estimated Implementation Time:** 2-3 hours
**Difficulty:** Medium
**Dependencies:** PostgreSQL + Redis running, monitor app configured

