# ECHO Multi-Agent System - Demo Guide

This guide walks you through demonstrating the ECHO system's capabilities using Claude Desktop.

## Prerequisites

Before starting the demo:

1. ✅ PostgreSQL running with `echo_org_dev` database
2. ✅ Redis running on localhost:6379
3. ✅ All agents built (`mix escript.build` in each agent directory)
4. ✅ Claude Desktop configured with at least CEO, CTO, and Product Manager
5. ✅ Migrations run (`cd shared && mix ecto.migrate`)

**Quick check:**
```bash
./echo.sh summary
```

Expected output should show "OPERATIONAL" status.

---

## Demo 1: Single Agent Autonomous Decision

**Scenario:** CEO approves a strategic initiative within their authority

**In Claude Desktop:**
```
Please use the CEO agent to approve a strategic initiative:
- Name: "AI Research Lab"
- Description: "Establish R&D facility for AI capabilities"
- Budget: $750,000
- Expected outcome: "Advanced AI product features by Q3 2026"
```

**What to observe:**
- ✅ CEO makes autonomous decision (budget under $1M limit)
- ✅ Decision stored in database
- ✅ No escalation needed

**Verify in terminal:**
```bash
# Check decision was recorded
psql echo_org_dev -c "SELECT id, type, mode, status FROM decisions ORDER BY inserted_at DESC LIMIT 1;"

# Check agent heartbeat
./echo.sh agents
```

**Expected Result:**
```
Decision ID: dec_xxxxx
Type: strategic_initiative
Mode: autonomous
Status: approved
```

---

## Demo 2: Autonomous Decision with Escalation

**Scenario:** CEO encounters decision exceeding their authority

**In Claude Desktop:**
```
Use the CEO agent to approve a strategic initiative:
- Name: "Enterprise Expansion"
- Description: "Open 5 new regional offices"
- Budget: $15,000,000
- Expected outcome: "50% revenue growth"
```

**What to observe:**
- ⚠️ CEO detects budget exceeds $1M authority limit
- 🔺 Escalates to human-in-the-loop mode
- 📋 Creates decision record with "requires_human_approval" status

**Verify:**
```bash
psql echo_org_dev -c "SELECT id, type, mode, status, escalation_reason FROM decisions ORDER BY inserted_at DESC LIMIT 1;"
```

**Expected Result:**
```
Mode: human
Status: pending
Escalation reason: "Budget $15,000,000 exceeds CEO autonomous authority ($1,000,000)"
```

---

## Demo 3: Inter-Agent Communication

**Scenario:** Product Manager sends message to CTO

**In Claude Desktop:**
```
1. Use the Product Manager to send a technical review request to the CTO:
   "Please review the feasibility of real-time collaboration features"

2. Check if the CTO received the message
```

**What to observe:**
- 📤 Product Manager publishes message to Redis
- 💾 Message stored in database (dual-write pattern)
- 📥 CTO receives message via pub/sub subscription

**Verify:**
```bash
# Check message was created
psql echo_org_dev -c "SELECT from_role, to_role, type, subject, read FROM messages ORDER BY inserted_at DESC LIMIT 1;"

# Monitor message queue
./echo.sh messages
```

**Expected Result:**
```
from_role: product_manager
to_role: cto
subject: Technical Review Request
read: false (until CTO processes it)
```

---

## Demo 4: Collaborative Decision

**Scenario:** Multiple agents vote on a technical decision

**In Claude Desktop:**
```
We need to decide on a technology stack for our new microservices platform.

1. Have the CTO propose: "Elixir, Phoenix, PostgreSQL, Redis architecture"
2. Ask Product Manager, Senior Architect, and Operations Head to vote
3. Tally the votes and make a collaborative decision
```

**What to observe:**
- 🗳️ CTO creates collaborative decision
- 📢 Notification sent to all participants
- ✅ Each agent casts vote (approve/reject with reasoning)
- 📊 Decision finalized based on consensus

**Verify:**
```bash
# Check decision record
psql echo_org_dev -c "SELECT id, type, mode, status FROM decisions WHERE mode = 'collaborative' ORDER BY inserted_at DESC LIMIT 1;"

# Check votes
psql echo_org_dev -c "SELECT voter_role, vote, reasoning FROM decision_votes WHERE decision_id = 'dec_xxxxx';"
```

---

## Demo 5: Hierarchical Escalation

**Scenario:** Technical decision escalates up the chain

**In Claude Desktop:**
```
A senior developer wants to introduce a new database technology (CockroachDB).

1. Senior Architect reviews the proposal
2. If uncertain, escalate to CTO
3. If strategic impact, CTO escalates to CEO
```

**What to observe:**
- 👨‍💼 Senior Architect uses hierarchical mode
- ⬆️ Escalates to CTO (direct report)
- ⬆️⬆️ CTO may escalate to CEO if strategic
- 📝 Full audit trail of escalation path

**Verify:**
```bash
psql echo_org_dev -c "SELECT id, mode, escalated_to, escalation_reason FROM decisions WHERE mode = 'hierarchical' ORDER BY inserted_at DESC LIMIT 1;"
```

---

## Demo 6: Multi-Agent Workflow

**Scenario:** Complete feature development lifecycle

**In Claude Desktop:**
```
I want to build a new feature: "Customer Analytics Dashboard"

Please coordinate with the ECHO team to:
1. Product Manager: Define requirements and business value
2. Senior Architect: Design system architecture
3. CTO: Review and approve technical approach
4. UI/UX Engineer: Create interface mockups
5. Senior Developer: Estimate implementation effort
6. Test Lead: Define testing strategy
7. CEO: Approve final budget and timeline

Work through this step by step, showing agent communications and decisions.
```

**What to observe:**
- 🔄 Multiple agents collaborate
- 📨 Inter-agent messages exchanged
- 🎯 Each agent performs role-specific tasks
- 📊 Decisions made at appropriate authority levels
- 🧵 Complete workflow execution

**Verify:**
```bash
# Monitor real-time activity
watch -n 2 './echo.sh summary'

# Check message flow
./echo.sh messages

# View workflow execution (if using workflow engine)
psql echo_org_dev -c "SELECT id, workflow_name, status, current_step, total_steps FROM workflow_executions ORDER BY inserted_at DESC LIMIT 1;"
```

---

## Demo 7: Agent Crash Recovery

**Scenario:** Agent goes down and recovers unprocessed messages

**Setup:**
```bash
# Terminal 1: Monitor agent health
watch -n 1 './echo.sh agents'

# Terminal 2: Send message while agent is "offline"
cd shared
mix run -e "
  alias EchoShared.MessageBus
  {:ok, msg_id} = MessageBus.publish_message(:product_manager, :ceo, :request, \"Urgent: Budget Approval\", %{amount: 500000})
  IO.puts(\"Message sent: #{msg_id}\")
"
```

**In Claude Desktop:**
```
Have the CEO agent catch up on any unread messages
```

**What to observe:**
- 💾 Message persisted in database (even if CEO was "offline")
- 🔄 CEO fetches unread messages on startup
- ✅ CEO processes missed message
- 📝 Message marked as read after processing

**Verify:**
```bash
# Check message was processed
psql echo_org_dev -c "SELECT id, subject, read, processed_at FROM messages WHERE to_role = 'ceo' ORDER BY inserted_at DESC LIMIT 5;"
```

---

## Demo 8: System Health Monitoring

**Scenario:** Real-time system observability

**In Terminal:**
```bash
# Full system status
./echo.sh

# Quick summary
./echo.sh summary

# Watch agent health
watch -n 2 './echo.sh agents'

# Monitor workflows
./echo.sh workflows

# Check message queue
./echo.sh messages

# Decision pipeline
./echo.sh decisions
```

**Expected Output Example:**
```
╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸
  System Summary
╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸

  ● System Status: OPERATIONAL

  Infrastructure:
    ✓ PostgreSQL
    ✓ Redis

  Agents:
    ✓ 3 / 9 agents healthy

  Active Workflows: 0
  Pending Decisions: 2
  Unread Messages: 5
```

---

## Demo 9: Decision Audit Trail

**Scenario:** Review complete decision history

**In Terminal:**
```bash
# All decisions
psql echo_org_dev -c "
SELECT
  id,
  type,
  mode,
  status,
  to_char(inserted_at, 'YYYY-MM-DD HH24:MI:SS') as created
FROM decisions
ORDER BY inserted_at DESC
LIMIT 10;
"

# Collaborative decisions with votes
psql echo_org_dev -c "
SELECT
  d.id,
  d.type,
  d.status,
  COUNT(dv.id) as vote_count,
  SUM(CASE WHEN dv.vote = 'approve' THEN 1 ELSE 0 END) as approvals
FROM decisions d
LEFT JOIN decision_votes dv ON d.id = dv.decision_id
WHERE d.mode = 'collaborative'
GROUP BY d.id, d.type, d.status;
"

# Escalation chain
psql echo_org_dev -c "
SELECT
  id,
  type,
  mode,
  escalated_to,
  escalation_reason
FROM decisions
WHERE escalated_to IS NOT NULL
ORDER BY inserted_at DESC;
"
```

---

## Demo 10: Performance Under Load

**Scenario:** System handles multiple concurrent operations

**Setup Script (`demo_load_test.exs`):**
```elixir
alias EchoShared.{MessageBus, AgentHealthMonitor}

# Simulate 50 concurrent messages
tasks = for i <- 1..50 do
  Task.async(fn ->
    MessageBus.publish_message(
      :product_manager,
      :ceo,
      :request,
      "Request #{i}",
      %{priority: :normal}
    )
  end)
end

results = Task.await_many(tasks, 5000)
IO.puts("Sent #{length(results)} messages")

# Simulate agent heartbeats
Enum.each([:ceo, :cto, :product_manager], fn role ->
  AgentHealthMonitor.record_heartbeat(role, %{
    version: "1.0.0",
    status: "healthy"
  })
end)
```

**Run:**
```bash
cd shared
mix run demo_load_test.exs

# Monitor system
./echo.sh summary
```

**What to observe:**
- ⚡ All messages processed
- 💪 No message loss
- 📊 System remains healthy
- ✅ All heartbeats recorded

---

## Troubleshooting Common Issues

### Agent Not Responding

```bash
# Check if agent process is running
ps aux | grep ceo

# Check agent health
./echo.sh agents

# View recent errors
psql echo_org_dev -c "SELECT to_role, processing_error FROM messages WHERE processing_error IS NOT NULL LIMIT 10;"
```

### Messages Not Being Delivered

```bash
# Check Redis is running
redis-cli ping

# Check message queue
./echo.sh messages

# Verify database connection
psql echo_org_dev -c "SELECT COUNT(*) FROM messages;"
```

### Database Issues

```bash
# Check PostgreSQL is running
pg_isready

# Re-run migrations
cd shared
mix ecto.migrate

# Check for migration errors
mix ecto.migrations
```

---

## Demo Checklist

Before presenting to stakeholders:

- [ ] All infrastructure running (PostgreSQL, Redis)
- [ ] All agents built and tested individually
- [ ] Claude Desktop configured with all agents
- [ ] Test data cleared: `cd shared && mix run -e "EchoShared.Repo.delete_all(EchoShared.Schemas.Message)"`
- [ ] Monitoring script working: `./echo.sh summary`
- [ ] Sample decisions prepared
- [ ] Multi-agent workflow tested end-to-end
- [ ] Recovery scenario tested
- [ ] Performance benchmarks run

---

## Advanced Scenarios

### Custom Workflow Execution

See `workflows/examples/feature_development.exs` for complete workflow definitions.

Run from iex:
```elixir
iex -S mix

alias EchoShared.Workflow.{Engine, Definition}

# Load workflow definition
{definition, _} = Code.eval_file("workflows/examples/feature_development.exs")

# Execute
{:ok, execution_id} = Engine.execute_workflow(definition, %{
  feature_name: "Customer Dashboard",
  priority: :high
})

# Monitor progress
Engine.get_execution_status(execution_id)
```

### Integration with External Systems

Agents can be extended to integrate with:
- GitHub (via MCP GitHub tools)
- Slack (notifications)
- Jira (ticket management)
- CI/CD pipelines

See `AGENT_INTEGRATION_GUIDE.md` for details.

---

## Metrics to Showcase

During demo, highlight these metrics:

1. **Response Time**: Agent tool execution < 100ms
2. **Message Throughput**: 1000+ messages/minute
3. **Decision Latency**: Autonomous < 50ms, Collaborative < 5s
4. **Crash Recovery**: Missed messages processed on restart
5. **Availability**: Agent health monitoring with 30s timeout
6. **Audit Trail**: Complete history of all decisions and messages

---

## Demo Script Template

**Opening:**
> "Today I'll demonstrate ECHO - an AI-powered organizational model where autonomous agents collaborate through the Model Context Protocol. Each agent has specific roles, decision-making authority, and can communicate with other agents in real-time."

**Demo 1-3:**
> "Let's start with single-agent autonomous decisions, then show escalation when authority limits are exceeded."

**Demo 4-6:**
> "Now let's see multi-agent collaboration - agents communicating, voting, and working together on complex tasks."

**Demo 7-8:**
> "A key feature is reliability - agents can crash and recover without losing messages, and we have comprehensive monitoring."

**Demo 9-10:**
> "Finally, let's look at the audit trail and system performance under load."

**Closing:**
> "ECHO provides a framework for building autonomous AI organizations with proper governance, collaboration patterns, and human oversight when needed."

---

## Next Steps After Demo

1. **Add Remaining Agents**: Connect all 9 agents to Claude Desktop
2. **Define Custom Workflows**: Create workflows specific to your use case
3. **Integrate External Systems**: Connect to GitHub, Slack, etc.
4. **Production Deployment**: Deploy to production infrastructure
5. **Scale Testing**: Test with higher loads and more complex workflows

## Resources

- `CLAUDE_DESKTOP_SETUP.md` - Setup instructions
- `AGENT_INTEGRATION_GUIDE.md` - Agent implementation details
- `DISTRIBUTED_SYSTEMS_IMPROVEMENTS.md` - Architecture details
- `ECHO_ARCHITECTURE.md` - Complete system design
- `ECHO_SH_README.md` - Monitoring script documentation
