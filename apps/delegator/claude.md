# delegator/

**Context:** Intelligent Agent Coordinator for ECHO

The Delegator is an MCP server that solves ECHO's resource utilization problem by spawning only the agents needed for a specific session, rather than running all 9 agents simultaneously.

## Purpose

The Delegator provides:
- **Intelligent Agent Selection** - Analyze tasks and spawn only required agents
- **Session Management** - Track agent lifecycles within user sessions
- **Resource Optimization** - Reduce CPU/memory usage by 50-80%
- **Dynamic Scaling** - Add/remove agents mid-session as needed
- **Task Routing** - Route messages to appropriate active agents

## Key Benefits

- ⚡ **Reduced CPU Usage** - Run 2-4 agents instead of 9
- 🚀 **Faster Startup** - Load only necessary LLMs (~7-14GB vs ~48GB)
- 🎯 **Better UX** - Relevant agents for the task at hand
- 💰 **Resource Efficiency** - Scale based on actual needs
- 🧩 **Extensible** - Support for dynamic mid-session spawning

## Architecture

### Before Delegator
```
Claude Desktop / MCP Client
    ├──> 9 Independent Agent MCP Servers (ALL running)
    │    └──> Each has specialized LLM via Ollama (~48GB total)
    │
    └──> Shared Infrastructure
         ├── PostgreSQL
         └── Redis
```

**Problem:** All 9 agents always running, even for simple tasks

### With Delegator
```
Claude Desktop / MCP Client
    ├──> Delegator MCP Server (intelligent coordinator)
    │    └──> Spawns only required agents per session
    │         ├──> Developer (for code tasks)
    │         ├──> Test Lead (if testing needed)
    │         └──> CEO (if strategic decision needed)
    │
    └──> Shared Infrastructure
         ├── PostgreSQL (+ delegator_sessions table)
         └── Redis
```

**Solution:** Delegate spawns 2-4 relevant agents based on task analysis

## Example Usage

### Simple Bug Fix
```
User: "Fix typo in README"

Delegator Analysis:
- Task type: Code change (documentation)
- Complexity: Low
- Required agents: Developer (1 agent)

Spawns: Developer (deepseek-coder:6.7b)
Resource usage: ~7GB memory, low CPU
Time saved: 80% faster startup
```

### Feature Implementation
```
User: "Add user authentication feature"

Delegator Analysis:
- Task type: Feature development
- Complexity: Medium
- Required agents: Product Manager, Architect, Developer, Test Lead (4 agents)

Spawns: PM, Architect, Dev, Test (4 agents)
Resource usage: ~20GB memory, medium CPU
Time saved: 55% faster startup
```

### Strategic Planning
```
User: "Plan Q2 roadmap and budget allocation"

Delegator Analysis:
- Task type: Strategic planning
- Complexity: High
- Required agents: CEO, Product Manager, Operations (3 agents)

Spawns: CEO, PM, Ops (3 agents)
Resource usage: ~16GB memory, medium CPU
Time saved: 66% faster startup
```

## Directory Structure

```
apps/delegator/
├── claude.md              # This file
├── README.md             # Project documentation
├── mix.exs               # Dependencies + configuration
├── lib/
│   ├── delegator.ex      # Main MCP server module
│   └── delegator/
│       ├── application.ex        # OTP application
│       ├── cli.ex               # Command-line interface
│       ├── task_analyzer.ex     # Analyze task requirements
│       ├── agent_spawner.ex     # Spawn/manage agent processes
│       ├── session_manager.ex   # Track active sessions
│       └── message_router.ex    # Route messages to agents
├── test/
│   ├── delegator_test.exs
│   ├── task_analyzer_test.exs
│   └── agent_spawner_test.exs
└── config/
    └── config.exs
```

## MCP Tools

The Delegator provides these MCP tools:

### 1. `create_session`

Create a new delegated agent session for a task

**Input:**
```json
{
  "task_description": "Implement user authentication",
  "context": {
    "priority": "high",
    "deadline": "2025-12-01",
    "existing_code": "apps/auth/"
  }
}
```

**Output:**
```json
{
  "session_id": "session_20251112_143022_84329",
  "active_agents": ["product_manager", "senior_architect", "senior_developer", "test_lead"],
  "estimated_resources": {
    "memory_gb": 20,
    "cpu_cores": 4
  },
  "status": "ready"
}
```

### 2. `analyze_task`

Analyze a task and recommend required agents (without spawning)

**Input:**
```json
{
  "task_description": "Fix typo in README",
  "analyze_only": true
}
```

**Output:**
```json
{
  "task_type": "code_change",
  "complexity": "low",
  "recommended_agents": ["senior_developer"],
  "reasoning": "Simple documentation fix requires only developer",
  "estimated_time": "5 minutes"
}
```

### 3. `add_agent_to_session`

Dynamically add an agent to running session

**Input:**
```json
{
  "session_id": "session_20251112_143022_84329",
  "agent_role": "ceo",
  "reason": "Need strategic approval for approach"
}
```

**Output:**
```json
{
  "agent_role": "ceo",
  "status": "spawned",
  "model": "qwen2.5:14b",
  "ready_in_seconds": 15
}
```

### 4. `remove_agent_from_session`

Remove an agent from session when no longer needed

**Input:**
```json
{
  "session_id": "session_20251112_143022_84329",
  "agent_role": "test_lead",
  "reason": "Testing completed"
}
```

**Output:**
```json
{
  "agent_role": "test_lead",
  "status": "terminated",
  "resources_freed_gb": 8
}
```

### 5. `list_active_sessions`

List all active delegator sessions

**Output:**
```json
{
  "sessions": [
    {
      "session_id": "session_20251112_143022_84329",
      "task_description": "Implement user authentication",
      "active_agents": ["product_manager", "senior_developer"],
      "created_at": "2025-11-12T14:30:22Z",
      "uptime_minutes": 45
    }
  ],
  "total_sessions": 1
}
```

### 6. `end_session`

End a delegated session and clean up agents

**Input:**
```json
{
  "session_id": "session_20251112_143022_84329"
}
```

**Output:**
```json
{
  "session_id": "session_20251112_143022_84329",
  "agents_terminated": ["product_manager", "senior_developer", "test_lead"],
  "resources_freed_gb": 18,
  "session_duration_minutes": 47
}
```

## Task Analysis Logic

### TaskAnalyzer Module

```elixir
defmodule Delegator.TaskAnalyzer do
  @doc """
  Analyze task description and recommend required agents
  """
  def analyze(task_description, context \\ %{}) do
    task_type = classify_task(task_description)
    complexity = determine_complexity(task_description, context)
    agents = recommend_agents(task_type, complexity)

    %{
      task_type: task_type,
      complexity: complexity,
      recommended_agents: agents,
      reasoning: explain_recommendation(task_type, complexity, agents)
    }
  end

  defp classify_task(description) do
    cond do
      matches?(description, ~r/bug|fix|error|issue/i) -> :bug_fix
      matches?(description, ~r/feature|add|implement|create/i) -> :feature_development
      matches?(description, ~r/refactor|cleanup|optimize/i) -> :refactoring
      matches?(description, ~r/test|qa|quality/i) -> :testing
      matches?(description, ~r/design|architecture|system/i) -> :architecture
      matches?(description, ~r/plan|strategy|roadmap|budget/i) -> :strategic_planning
      matches?(description, ~r/ui|ux|interface|design/i) -> :ui_design
      matches?(description, ~r/deploy|release|production/i) -> :deployment
      true -> :general
    end
  end

  defp determine_complexity(description, context) do
    indicators = [
      has_deadline?(context),
      is_critical?(context),
      is_large_scope?(description),
      requires_coordination?(description)
    ]

    case Enum.count(indicators, & &1) do
      0 -> :low
      1 -> :low
      2 -> :medium
      3 -> :high
      4 -> :very_high
    end
  end

  defp recommend_agents(:bug_fix, :low), do: [:senior_developer]
  defp recommend_agents(:bug_fix, :medium), do: [:senior_developer, :test_lead]
  defp recommend_agents(:bug_fix, :high), do: [:senior_developer, :test_lead, :senior_architect]

  defp recommend_agents(:feature_development, :low), do: [:senior_developer, :test_lead]
  defp recommend_agents(:feature_development, :medium), do: [:product_manager, :senior_developer, :test_lead]
  defp recommend_agents(:feature_development, :high), do: [:product_manager, :senior_architect, :senior_developer, :test_lead]

  defp recommend_agents(:strategic_planning, _), do: [:ceo, :product_manager, :operations_head]

  defp recommend_agents(:architecture, _), do: [:cto, :senior_architect, :senior_developer]

  defp recommend_agents(:ui_design, _), do: [:uiux_engineer, :senior_developer]

  # ... more mappings
end
```

## Session Management

### Database Schema

The delegator uses a `delegator_sessions` table:

```sql
CREATE TABLE delegator_sessions (
  id UUID PRIMARY KEY,
  task_description TEXT NOT NULL,
  task_type VARCHAR(50),
  complexity VARCHAR(20),
  active_agents JSONB,  -- ["ceo", "cto"]
  context JSONB,
  status VARCHAR(20),   -- "active", "completed", "failed"
  created_at TIMESTAMP DEFAULT NOW(),
  ended_at TIMESTAMP,
  resources_used JSONB  -- {"memory_gb": 20, "cpu_cores": 4}
);
```

### SessionManager Module

```elixir
defmodule Delegator.SessionManager do
  alias EchoShared.Repo
  alias Delegator.Schemas.Session

  def create_session(task_description, context, agents) do
    %Session{}
    |> Session.changeset(%{
      task_description: task_description,
      task_type: context[:task_type],
      complexity: context[:complexity],
      active_agents: agents,
      context: context,
      status: "active"
    })
    |> Repo.insert()
  end

  def add_agent(session_id, agent_role) do
    session = Repo.get!(Session, session_id)
    updated_agents = [agent_role | session.active_agents] |> Enum.uniq()

    session
    |> Session.changeset(%{active_agents: updated_agents})
    |> Repo.update()
  end

  def end_session(session_id) do
    session = Repo.get!(Session, session_id)

    session
    |> Session.changeset(%{status: "completed", ended_at: DateTime.utc_now()})
    |> Repo.update()
  end
end
```

## Agent Spawning

### AgentSpawner Module

```elixir
defmodule Delegator.AgentSpawner do
  @agent_paths %{
    ceo: "apps/ceo/ceo",
    cto: "apps/cto/cto",
    senior_developer: "apps/senior_developer/senior_developer"
    # ... other agents
  }

  def spawn_agent(agent_role, session_id) do
    executable = @agent_paths[agent_role]

    port = Port.open({:spawn_executable, executable}, [
      :binary,
      :exit_status,
      {:env, [{'SESSION_ID', to_charlist(session_id)}]},
      {:args, ['--autonomous']}
    ])

    track_agent(session_id, agent_role, port)
    {:ok, port}
  end

  def terminate_agent(session_id, agent_role) do
    case get_agent_port(session_id, agent_role) do
      nil -> {:error, :not_found}
      port ->
        Port.close(port)
        untrack_agent(session_id, agent_role)
        {:ok, :terminated}
    end
  end

  defp track_agent(session_id, agent_role, port) do
    # Store in ETS or Agent state
    :ets.insert(:delegator_agents, {{session_id, agent_role}, port})
  end

  defp get_agent_port(session_id, agent_role) do
    case :ets.lookup(:delegator_agents, {session_id, agent_role}) do
      [{{^session_id, ^agent_role}, port}] -> port
      [] -> nil
    end
  end
end
```

## Message Routing

When an agent needs to communicate with another agent in the session:

```elixir
defmodule Delegator.MessageRouter do
  def route_message(session_id, from_role, to_role, message) do
    # 1. Check if target agent is active in session
    case get_active_agents(session_id) do
      agents when to_role in agents ->
        # Agent is active, route message
        EchoShared.MessageBus.send_message(from_role, to_role, message)

      _ ->
        # Agent not active, suggest spawning
        {:error, :agent_not_active, suggest_spawn: to_role}
    end
  end
end
```

## Development & Testing

### Running Delegator

```bash
cd apps/delegator

# Compile
mix deps.get
mix compile

# Run tests
mix test

# Build executable
mix escript.build

# Run as MCP server
./delegator

# Run in autonomous mode (testing)
./delegator --autonomous
```

### Testing Scenarios

```bash
# Test task analysis
iex> Delegator.TaskAnalyzer.analyze("Fix typo in README")
%{
  task_type: :bug_fix,
  complexity: :low,
  recommended_agents: [:senior_developer],
  reasoning: "Simple documentation fix"
}

# Test session creation
iex> Delegator.create_session("Implement auth", %{priority: "high"})
{:ok, %{session_id: "session_...", active_agents: [...]}}

# Test agent spawning
iex> Delegator.AgentSpawner.spawn_agent(:senior_developer, session_id)
{:ok, #Port<0.123>}
```

## Configuration

```elixir
# config/config.exs
config :delegator,
  agent_paths: %{
    ceo: "/path/to/echo/apps/ceo/ceo",
    cto: "/path/to/echo/apps/cto/cto"
    # ... other agents
  },
  max_concurrent_sessions: 10,
  session_timeout_minutes: 60,
  auto_cleanup_agents: true

# Complexity thresholds
config :delegator, :complexity_rules,
  low: %{max_agents: 2, max_memory_gb: 10},
  medium: %{max_agents: 4, max_memory_gb: 25},
  high: %{max_agents: 6, max_memory_gb: 40},
  very_high: %{max_agents: 9, max_memory_gb: 50}
```

## Performance Metrics

### Resource Savings

| Task Type | Before (9 agents) | After (delegator) | Savings |
|-----------|-------------------|-------------------|---------|
| Simple bug fix | 48GB, 9 agents | 7GB, 1 agent | 85% memory, 89% agents |
| Feature dev | 48GB, 9 agents | 20GB, 4 agents | 58% memory, 56% agents |
| Strategic plan | 48GB, 9 agents | 16GB, 3 agents | 67% memory, 67% agents |
| Architecture | 48GB, 9 agents | 25GB, 3 agents | 48% memory, 67% agents |

**Average savings: 65% memory, 70% agents**

### Startup Time

| Scenario | Before | After | Improvement |
|----------|--------|-------|-------------|
| Simple task | 45s (load all 9) | 8s (load 1) | 82% faster |
| Medium task | 45s (load all 9) | 20s (load 4) | 56% faster |
| Complex task | 45s (load all 9) | 35s (load 6) | 22% faster |

## Troubleshooting

### Session not created
**Symptom:** `create_session` returns error

**Debug:**
```elixir
iex> Delegator.TaskAnalyzer.analyze("your task")
# Check if task analysis works

iex> EchoShared.Repo.all(Delegator.Schemas.Session)
# Check database connection
```

### Agent not spawning
**Symptom:** Agent doesn't start

**Debug:**
```bash
# Test agent executable directly
cd apps/senior_developer
./senior_developer --autonomous

# Check executable exists
ls -la apps/*/senior_developer
```

### High memory usage despite delegator
**Symptom:** Memory usage still high

**Debug:**
```bash
# Check active sessions
iex> Delegator.list_active_sessions()

# Check agent processes
ps aux | grep -E "ceo|cto|developer"

# Clean up orphaned agents
iex> Delegator.cleanup_orphaned_agents()
```

## Future Enhancements

**Phase 2: Intelligent Mid-Session Adaptation**
- Auto-spawn agents when task complexity increases
- Auto-terminate agents when no longer needed
- Predictive spawning based on task patterns

**Phase 3: Cost Optimization**
- Track $ cost per session (LLM inference)
- Recommend cheaper model alternatives
- Budget-aware agent selection

**Phase 4: Multi-Session Orchestration**
- Share agents across multiple sessions
- Agent pooling for frequently used roles
- Load balancing across sessions

## Related Documentation

- **Architecture:** [../../docs/architecture/DELEGATOR_ARCHITECTURE.md](../../docs/architecture/DELEGATOR_ARCHITECTURE.md)
- **Quick Start:** [../../docs/guides/DELEGATOR_QUICK_START.md](../../docs/guides/DELEGATOR_QUICK_START.md)
- **Parent:** [../../CLAUDE.md](../../CLAUDE.md) - Project overview
- **Agents:** [../claude.md](../claude.md) - Agent development patterns

---

**Remember:** The Delegator is about efficiency. Spawn only what's needed, cleanup when done.
