# ECHO Workflows

Multi-agent collaboration workflows for the ECHO organizational model.

## Overview

Workflows orchestrate complex, multi-step tasks that require collaboration between multiple ECHO agents. The workflow engine coordinates agent actions, manages decision-making patterns, and ensures proper escalation and approval flows.

## Decision Patterns

### 1. Autonomous
Single agent makes decision within their authority boundaries.

**Example:** CTO approves technical proposal under $500K

### 2. Collaborative
Multiple agents work together to reach consensus.

**Example:** Product roadmap planning (PM + CTO + Senior Architect)

### 3. Hierarchical
Decision escalates up the reporting chain when authority is exceeded.

**Example:** Budget request over limit escalates to CEO

### 4. Human-in-the-Loop
Workflow pauses for human approval/input.

**Example:** Legal decisions, terminations, strategic pivots

## Workflow Structure

```elixir
alias EchoShared.Workflow.Definition

Definition.new(
  "workflow_name",
  "Description of what this workflow does",
  [:participant1, :participant2],  # List of agents involved
  [
    # Step 1: Send notification
    {:notify, :agent_role, "Message content"},

    # Step 2: Request action from agent
    {:request, :agent_role, "action_type", %{data: "value"}},

    # Step 3: Pause for human approval
    {:pause, "Reason for pausing"},

    # Step 4: Record decision
    {:decision, %{type: "decision_type", mode: :collaborative}},

    # Step 5: Parallel execution
    {:parallel, [
      {:request, :agent1, "action", %{}},
      {:request, :agent2, "action", %{}}
    ]},

    # Step 6: Conditional branch
    {:conditional,
      fn context -> context[:condition] == true end,
      {:notify, :agent1, "Condition true"},
      {:notify, :agent2, "Condition false"}
    }
  ]
)
```

## Step Types

### notify
Send one-way notification to an agent.

```elixir
{:notify, :cto, "Technical review needed"}
```

### request
Send request to agent and expect action (async).

```elixir
{:request, :senior_architect, "review_architecture", %{
  proposal_id: "arch_001",
  focus: ["scalability", "security"]
}}
```

### pause
Pause workflow execution for human input.

```elixir
{:pause, "Need CEO approval for budget"}
```

### decision
Record organizational decision in database.

```elixir
{:decision, %{
  type: "feature_approval",
  mode: :collaborative,
  participants: [:product_manager, :cto]
}}
```

### parallel
Execute multiple steps simultaneously.

```elixir
{:parallel, [
  {:request, :senior_developer, "implement_feature", %{}},
  {:request, :test_lead, "create_test_plan", %{}}
]}
```

### conditional
Branch execution based on condition.

```elixir
{:conditional,
  fn context -> context[:budget] > 500_000 end,
  {:request, :ceo, "approve_budget", %{}},  # If true
  {:notify, :cto, "Budget pre-approved"}     # If false
}
```

## Example Workflows

### Feature Development
**File:** `examples/feature_development.exs`

Complete workflow from feature concept to release:
1. PM creates requirement
2. Architect reviews feasibility
3. UI/UX designs interface
4. PM approves design
5. Dev implements + Test plans (parallel)
6. Test validates quality
7. PM approves release

**Participants:** PM, Senior Architect, UI/UX, Senior Dev, Test Lead

### Hiring
**File:** `examples/hiring.exs`

Hierarchical hiring workflow with budget escalation:
1. CTO creates requisition
2. CHRO reviews budget
3. Escalate to CEO if over budget
4. CHRO approves and posts job
5. Pause for candidates
6. Technical interviews (parallel)
7. CHRO makes offer decision

**Participants:** CTO, CHRO, Senior Architect, (CEO for escalation)

## Running Workflows

### Programmatically

```elixir
# Load workflow definition
{workflow, _} = Code.eval_file("workflows/examples/feature_development.exs")

# Execute workflow
{:ok, execution_id} = EchoShared.Workflow.Engine.execute_workflow(workflow, %{
  feature_name: "User Dashboard",
  priority: "high"
})

# Check status
{:ok, execution} = EchoShared.Workflow.Engine.get_status(execution_id)
IO.inspect(execution.status)  # :running, :paused, :completed, :failed
```

### Resume Paused Workflow

```elixir
# When workflow pauses for human approval
{:ok, execution} = EchoShared.Workflow.Engine.get_status(execution_id)
# => execution.status == :paused

# Resume with approval data
:ok = EchoShared.Workflow.Engine.resume_workflow(execution_id, %{
  approved: true,
  approver: "jane@company.com",
  comments: "Approved with conditions"
})
```

## Creating New Workflows

### Step 1: Define Participants
Identify which agents need to be involved.

### Step 2: Map Out Steps
List all actions in sequential order.

### Step 3: Identify Decision Points
Mark where decisions need to be made (autonomous, collaborative, hierarchical).

### Step 4: Add Conditionals
Add branching logic for different scenarios.

### Step 5: Identify Pauses
Mark where human approval is needed.

### Step 6: Add Parallel Steps
Identify steps that can run simultaneously for efficiency.

### Example Template

```elixir
alias EchoShared.Workflow.Definition

Definition.new(
  "my_workflow_name",
  "Clear description of workflow purpose",
  [:agent1, :agent2, :agent3],
  [
    # Initial setup
    {:notify, :agent1, "Workflow started"},

    # Main workflow steps
    {:request, :agent1, "perform_action", %{data: "value"}},

    # Decision point
    {:conditional,
      fn ctx -> ctx[:needs_approval] end,
      {:pause, "Awaiting approval"},
      {:notify, :agent1, "Auto-approved"}
    },

    # Parallel execution for efficiency
    {:parallel, [
      {:request, :agent2, "task_a", %{}},
      {:request, :agent3, "task_b", %{}}
    ]},

    # Final decision record
    {:decision, %{
      type: "workflow_type",
      mode: :collaborative
    }}
  ],
  timeout: 3_600_000,  # 1 hour in milliseconds
  metadata: %{
    category: "operations",
    priority: "high",
    tags: ["example"]
  }
)
```

## Best Practices

### 1. Clear Naming
Use descriptive names for workflows and steps.

### 2. Error Handling
Always consider failure cases and timeouts.

### 3. Audit Trail
Use `:decision` steps to record important outcomes.

### 4. Efficient Execution
Use `:parallel` steps when tasks are independent.

### 5. Human Approval
Use `:pause` for decisions requiring human judgment.

### 6. Context Passing
Use execution context to pass data between steps.

### 7. Timeouts
Set reasonable timeouts based on workflow complexity.

## Troubleshooting

### Workflow Stuck in Running
- Check if any agent is down or unresponsive
- Review logs for step execution errors
- Verify message bus connectivity

### Workflow Never Completes
- Check for infinite loops in conditional logic
- Verify timeout is set appropriately
- Review parallel step coordination

### Pause Not Resuming
- Verify execution_id is correct
- Check that approval data format matches expectations
- Ensure workflow engine is running

## Integration with Agents

Agents receive workflow requests via Redis message bus:

```elixir
# In agent's message handler
def handle_info({:redix_pubsub, _, :message, %{payload: payload}}, state) do
  message = Jason.decode!(payload)

  case message["type"] do
    "request" ->
      # Execute requested action
      # Update workflow context if needed

    "notification" ->
      # Log notification
      # Take appropriate action
  end

  {:noreply, state}
end
```

## Testing Workflows

See `test/integration/workflow_test.exs` for examples.

```elixir
test "feature development workflow completes" do
  {workflow, _} = Code.eval_file("workflows/examples/feature_development.exs")
  {:ok, execution_id} = Engine.execute_workflow(workflow)

  # Wait for completion (or timeout)
  Process.sleep(5000)

  {:ok, execution} = Engine.get_status(execution_id)
  assert execution.status == :completed
end
```

## Future Enhancements

- [ ] Database persistence for workflow executions
- [ ] Workflow versioning
- [ ] Retry logic for failed steps
- [ ] Workflow templates library
- [ ] Visual workflow designer
- [ ] Real-time workflow monitoring dashboard
- [ ] Workflow analytics and insights

## Support

For issues or questions:
1. Check workflow logs: `grep "Workflow" logs/app.log`
2. Review execution status via `Engine.get_status/1`
3. Verify all agents are running and healthy
4. Check Redis connectivity

---

**Version:** 1.0.0
**Status:** Beta - Foundation Complete
