# workflows/

**Context:** Multi-Agent Workflow Definitions & Orchestration

This directory contains workflow definitions that coordinate multiple agents to complete complex organizational tasks.

## Purpose

Workflows enable:
- **Multi-agent coordination** - Sequential and parallel agent tasks
- **Decision orchestration** - Automated decision flows with proper authority
- **Human-in-the-loop** - Pause for human approval at critical points
- **Process automation** - Repeatable organizational processes

## Directory Structure

```
workflows/
├── claude.md              # This file
├── examples/              # Example workflow definitions
│   ├── feature_development.exs
│   ├── hiring_process.exs
│   ├── incident_response.exs
│   ├── strategic_planning.exs
│   └── budget_allocation.exs
└── README.md             # Workflow usage guide
```

## Workflow DSL

Workflows use the `EchoShared.Workflow.Definition` DSL:

```elixir
alias EchoShared.Workflow.Definition

Definition.new(
  "workflow_name",                  # Unique workflow identifier
  "Workflow description",           # Human-readable description
  [:list, :of, :participating_agents],  # Required agent roles
  [
    # Workflow steps (see below)
  ]
)
```

## Workflow Step Types

### 1. Request Step

Execute an agent tool:

```elixir
{:request, :agent_role, "tool_name", %{
  param1: "value1",
  param2: :from_previous_step  # Use output from previous step
}}
```

### 2. Decision Step

Trigger a decision with specified mode:

```elixir
{:decision, %{
  type: "budget_approval",
  mode: :autonomous,  # or :collaborative, :hierarchical, :human
  initiator: :ceo,
  context: %{amount: 500_000}
}}
```

### 3. Parallel Steps

Execute multiple steps concurrently:

```elixir
{:parallel, [
  {:request, :senior_developer, "implement_backend", %{}},
  {:request, :uiux_engineer, "design_ui", %{}},
  {:request, :test_lead, "create_test_plan", %{}}
]}
```

### 4. Conditional Step

Branch based on condition:

```elixir
{:conditional,
  fn context -> context.budget > 1_000_000 end,
  {:decision, %{mode: :human, reason: "High budget"}},
  {:decision, %{mode: :autonomous}}}
```

### 5. Pause Step

Wait for human approval:

```elixir
{:pause, "Awaiting executive approval before production deployment"}
```

### 6. Loop Step

Repeat steps:

```elixir
{:loop,
  fn context -> length(context.items) > 0 end,
  [
    {:request, :agent, "process_item", %{item: :from_context}}
  ]}
```

## Example Workflows

### Feature Development Workflow

```elixir
# workflows/examples/feature_development.exs

Definition.new(
  "feature_development",
  "Complete feature development from requirements to deployment",
  [:product_manager, :senior_architect, :cto, :senior_developer,
   :uiux_engineer, :test_lead, :ceo],
  [
    # Step 1: Product Manager defines feature
    {:request, :product_manager, "define_feature", %{
      name: :from_input,
      priority: :from_input
    }},

    # Step 2: Architect designs system
    {:request, :senior_architect, "design_system", %{
      requirements: :from_previous_step
    }},

    # Step 3: CTO reviews and approves architecture
    {:decision, %{
      type: "architecture_approval",
      mode: :autonomous,
      initiator: :cto,
      context: :from_previous_step
    }},

    # Step 4: Parallel implementation
    {:parallel, [
      {:request, :senior_developer, "implement_backend", %{
        design: :from_step_2
      }},
      {:request, :uiux_engineer, "design_ui", %{
        requirements: :from_step_1
      }}
    ]},

    # Step 5: Test Lead creates test plan
    {:request, :test_lead, "create_test_plan", %{
      implementation: :from_previous_step
    }},

    # Step 6: Budget approval
    {:decision, %{
      type: "budget_approval",
      mode: :autonomous,
      initiator: :ceo,
      context: %{estimated_cost: :from_context}
    }},

    # Step 7: Human approval for production
    {:pause, "Awaiting human approval for production deployment"}
  ]
)
```

### Hiring Process Workflow

```elixir
# workflows/examples/hiring_process.exs

Definition.new(
  "hiring_process",
  "Complete hiring workflow from job posting to offer",
  [:chro, :cto, :ceo],
  [
    # Step 1: CHRO posts job
    {:request, :chro, "post_job", %{
      position: :from_input,
      department: :from_input
    }},

    # Step 2: CTO reviews candidates (technical positions)
    {:conditional,
      fn ctx -> ctx.department == "engineering" end,
      {:request, :cto, "review_candidates", %{
        candidates: :from_context
      }},
      {:request, :chro, "review_candidates", %{}}
    },

    # Step 3: Interview scheduling
    {:request, :chro, "schedule_interviews", %{
      selected_candidates: :from_previous_step
    }},

    # Step 4: Offer approval
    {:decision, %{
      type: "offer_approval",
      mode: :collaborative,
      participants: [:chro, :cto, :ceo],
      context: %{
        candidate: :from_context,
        salary: :from_context
      }
    }},

    # Step 5: Send offer
    {:request, :chro, "send_offer", %{
      candidate: :from_context,
      approved_terms: :from_previous_step
    }}
  ]
)
```

### Incident Response Workflow

```elixir
# workflows/examples/incident_response.exs

Definition.new(
  "incident_response",
  "Handle production incidents",
  [:operations_head, :cto, :senior_developer, :ceo],
  [
    # Step 1: Operations Head assesses severity
    {:request, :operations_head, "assess_incident", %{
      incident_id: :from_input,
      description: :from_input
    }},

    # Step 2: Notify leadership if critical
    {:conditional,
      fn ctx -> ctx.severity == "critical" end,
      {:request, :operations_head, "notify_leadership", %{
        incident: :from_previous_step
      }},
      {:noop}
    },

    # Step 3: CTO approves mitigation plan
    {:decision, %{
      type: "mitigation_approval",
      mode: :autonomous,
      initiator: :cto,
      context: :from_step_1
    }},

    # Step 4: Implement fix
    {:request, :senior_developer, "deploy_hotfix", %{
      mitigation_plan: :from_previous_step
    }},

    # Step 5: Operations verifies resolution
    {:request, :operations_head, "verify_resolution", %{
      incident_id: :from_input
    }},

    # Step 6: CEO informed if customer-impacting
    {:conditional,
      fn ctx -> ctx.customer_impact == true end,
      {:request, :ceo, "customer_communication", %{
        incident_summary: :from_context
      }},
      {:noop}
    }
  ]
)
```

## Executing Workflows

### Start Workflow

```elixir
alias EchoShared.Workflow.Engine

# Load workflow definition
{:ok, workflow} = File.read("workflows/examples/feature_development.exs")
{:ok, definition} = Code.eval_string(workflow)

# Start execution
{:ok, execution_id} = Engine.start_workflow(definition, %{
  triggered_by: "ceo",
  input: %{
    name: "User Authentication",
    priority: "high"
  }
})
```

### Monitor Workflow

```elixir
# Check status
{:ok, status} = Engine.get_status(execution_id)
# => %{
#   workflow_name: "feature_development",
#   status: "running",
#   current_step: 3,
#   total_steps: 7,
#   started_at: ~U[...],
#   completed_steps: [
#     %{step: 1, agent: :product_manager, result: %{...}},
#     %{step: 2, agent: :senior_architect, result: %{...}}
#   ]
# }

# Get execution history
{:ok, history} = Engine.get_history(execution_id)
```

### Resume Paused Workflow

```elixir
# Resume after human approval
Engine.resume(execution_id, %{
  human_approval: true,
  approved_by: "john@company.com",
  notes: "Approved for production deployment"
})
```

### Cancel Workflow

```elixir
Engine.cancel(execution_id, "Requirements changed, no longer needed")
```

## Best Practices

### 1. Clear Step Names

Use descriptive names for workflow steps:

```elixir
# Good
{:request, :product_manager, "define_feature_requirements", %{...}}

# Bad
{:request, :product_manager, "do_thing", %{...}}
```

### 2. Handle Errors

Add error handling steps:

```elixir
[
  {:request, :agent, "risky_operation", %{}},
  {:conditional,
    fn ctx -> ctx.error != nil end,
    {:request, :agent, "handle_error", %{error: :from_context}},
    {:request, :agent, "continue_normal_flow", %{}}
  }
]
```

### 3. Context Management

Pass data between steps explicitly:

```elixir
[
  {:request, :pm, "define_feature", %{name: "Auth"}},
  # Store result in context
  {:assign, :feature_spec, :from_previous_step},
  # Use stored context later
  {:request, :architect, "design", %{spec: :feature_spec}}
]
```

### 4. Timeout Handling

Set timeouts for long-running steps:

```elixir
{:request, :agent, "long_operation", %{
  timeout: 300_000,  # 5 minutes
  on_timeout: :retry  # or :fail, :continue
}}
```

### 5. Idempotency

Ensure steps can be safely retried:

```elixir
def execute_tool("create_record", %{"id" => id} = args) do
  case Repo.get(Record, id) do
    nil -> Repo.insert(%Record{id: id, ...})  # Create if not exists
    record -> {:ok, record}  # Return existing
  end
end
```

## Testing Workflows

```elixir
defmodule WorkflowTest do
  use ExUnit.Case
  alias EchoShared.Workflow.Engine

  test "feature development workflow completes successfully" do
    {:ok, workflow} = load_workflow("feature_development")

    {:ok, execution_id} = Engine.start_workflow(workflow, %{
      input: %{name: "Test Feature", priority: "high"}
    })

    # Wait for completion
    assert_workflow_completes(execution_id, timeout: 30_000)

    # Verify results
    {:ok, status} = Engine.get_status(execution_id)
    assert status.status == "completed"
    assert length(status.completed_steps) == 7
  end

  test "workflow pauses for human approval" do
    {:ok, workflow} = load_workflow("feature_development")
    {:ok, execution_id} = Engine.start_workflow(workflow, %{...})

    # Should pause at step 7
    :timer.sleep(5000)
    {:ok, status} = Engine.get_status(execution_id)
    assert status.status == "paused"
    assert status.pause_reason == "Awaiting human approval..."

    # Resume
    Engine.resume(execution_id, %{human_approval: true})

    # Should complete
    assert_workflow_completes(execution_id)
  end
end
```

## Common Issues

### Workflow stuck in "running" state

**Cause:** Agent not responding to tool request

**Debug:**
```elixir
{:ok, status} = Engine.get_status(execution_id)
IO.inspect(status.current_step)
# Check agent logs for the stuck step
```

### Steps executing out of order

**Cause:** Parallel step without proper synchronization

**Solution:** Use explicit synchronization:
```elixir
{:parallel, [step1, step2, step3]},
{:wait_all},  # Wait for all parallel steps to complete
{:request, :next_agent, "next_step", %{}}
```

### Context not passing between steps

**Cause:** Incorrect context reference

**Solution:**
```elixir
# Explicit context passing
{:request, :agent1, "step1", %{}},
{:assign, :result1, :from_previous_step},
{:request, :agent2, "step2", %{input: :result1}}
```

## Environment Variables

```bash
# Workflow execution
WORKFLOW_TIMEOUT=3600000       # Default workflow timeout (1 hour)
WORKFLOW_STEP_TIMEOUT=300000   # Default step timeout (5 minutes)
WORKFLOW_RETRY_ATTEMPTS=3      # Retry failed steps
WORKFLOW_PARALLEL_LIMIT=5      # Max concurrent parallel steps

# Storage
WORKFLOW_EXECUTION_RETENTION=30  # Days to keep execution history
```

## Related Documentation

- **Parent:** [../CLAUDE.md](../CLAUDE.md) - Project overview
- **Shared Library:** [../shared/claude.md](../shared/claude.md) - Workflow engine API
- **Agents:** [../agents/claude.md](../agents/claude.md) - Agent tools used in workflows

---

**Remember:** Workflows coordinate agents but don't replace good agent design. Keep workflows simple and delegate complexity to agents.
