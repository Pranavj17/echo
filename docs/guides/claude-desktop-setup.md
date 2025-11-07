# ECHO Agents in Claude Desktop - Complete Guide

**Goal:** Use your 9 ECHO organizational agents as tools in Claude Desktop for real multi-agent coordination.

---

## What You'll Be Able to Do

After setup, you can have conversations like:

```
You: "I want to build a mobile dashboard feature. Budget is $200K.
     Can you coordinate with the ECHO team?"

Claude: "I'll help coordinate this! Let me start with the Product Manager..."

[Claude calls: echo-product-manager → create_feature_requirement]

Claude: "The PM has created the requirement. Now let me get the
        Senior Architect to review technical feasibility..."

[Claude calls: echo-senior-architect → review_technical_feasibility]

Claude: "The architect says this is high complexity and needs CTO approval.
        Let me escalate this..."

[Claude calls: echo-cto → approve_technical_proposal]

Claude: "Great! The CTO approved it. The budget is $200K which is within
        the PM's authority. Now for UI/UX design..."
```

**Each agent tool call:**
- ✅ Actually runs the agent escript
- ✅ Executes real business logic
- ✅ Records decisions in your PostgreSQL database
- ✅ Returns structured results to Claude
- ✅ Enables true multi-agent orchestration

---

## Prerequisites

### 1. Verify Everything Works

```bash
# Check infrastructure
pg_isready -h localhost
redis-cli ping

# Verify all agents
cd /Users/pranav/Documents/echo
./scripts/start_all_agents.sh
```

Should output:
```
✓ All agents verified successfully!
```

### 2. Check Claude Desktop is Installed

- Download from: https://claude.ai/download
- Install and open once
- Quit Claude Desktop (we'll configure it next)

---

## Step-by-Step Setup

### Step 1: Find Your Claude Desktop Config Directory

**On macOS:**
```bash
# Config directory
~/.config/Claude/

# If it doesn't exist, create it
mkdir -p ~/.config/Claude/
```

**On Windows:**
```
%APPDATA%\Claude\
```

**On Linux:**
```bash
~/.config/Claude/
```

### Step 2: Create the Configuration File

**Open your text editor:**
```bash
nano ~/.config/Claude/claude_desktop_config.json
```

**Or use VS Code:**
```bash
code ~/.config/Claude/claude_desktop_config.json
```

### Step 3: Add Your Agents (Start with 3 for Testing)

**Paste this configuration:**

```json
{
  "mcpServers": {
    "echo-product-manager": {
      "command": "/Users/pranav/Documents/echo/agents/product_manager/product_manager",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-senior-architect": {
      "command": "/Users/pranav/Documents/echo/agents/senior_architect/senior_architect",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-cto": {
      "command": "/Users/pranav/Documents/echo/agents/cto/cto",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    }
  }
}
```

**Important:** Replace `/Users/pranav/Documents/echo` with your actual path if different.

**Save and close the file.**

### Step 4: Restart Claude Desktop

1. **Quit Claude Desktop completely** (Cmd+Q on Mac, or close from system tray)
2. **Wait 5 seconds**
3. **Open Claude Desktop again**

### Step 5: Verify Agents Loaded

**Start a new conversation in Claude Desktop and say:**

```
Can you list the available ECHO agent tools?
```

**You should see output like:**

```
I can see three ECHO agent tools available:

**Product Manager (echo-product-manager):**
1. create_feature_requirement - Create a new feature requirement
2. approve_design - Approve a UI/UX design
3. approve_release - Approve a feature release
4. prioritize_backlog - Prioritize the product backlog
5. create_user_story - Create a user story
6. escalate_to_leadership - Escalate to CEO/CTO

**Senior Architect (echo-senior-architect):**
1. review_technical_feasibility - Review technical approach
2. review_architecture - Review system architecture
3. approve_technical_design - Approve technical design
4. assess_technical_debt - Assess technical debt
5. recommend_technology - Recommend technology choices
6. escalate_to_cto - Escalate to CTO

**CTO (echo-cto):**
1. approve_technical_proposal - Approve technical proposals
2. allocate_engineering_budget - Allocate engineering budget
3. review_architecture - Review architecture decisions
4. approve_infrastructure_change - Approve infrastructure changes
5. review_engineering_metrics - Review engineering metrics
6. escalate_to_ceo - Escalate to CEO
```

✅ **If you see this, setup is complete!**

---

## Using Your ECHO Agents

### Example 1: Simple Feature Development

**You:**
```
I want to build a mobile dashboard feature. Can you help me coordinate
with the Product Manager and Senior Architect to plan this?
```

**Claude will:**
1. Call `echo-product-manager.create_feature_requirement`
2. Show you the requirement created
3. Call `echo-senior-architect.review_technical_feasibility`
4. Show you the feasibility assessment
5. Decide next steps based on the architect's response

### Example 2: Budget Approval Workflow

**You:**
```
We need to build a new analytics platform. Estimated cost is $400K.
Walk me through the approval process with the ECHO team.
```

**Claude will:**
1. Create requirement with Product Manager
2. Get technical review from Senior Architect
3. Notice it's high complexity or high budget
4. Escalate to CTO for approval
5. CTO reviews and approves (within $500K authority)
6. Report back the approval

### Example 3: Check Organizational Health

**You:**
```
Can you ask the CTO to review our engineering metrics?
```

**Claude will:**
1. Call `echo-cto.review_engineering_metrics`
2. Show you the current metrics
3. Provide insights from the CTO's response

### Example 4: Multi-Agent Coordination

**You:**
```
I have a complex feature idea:
- Feature: Real-time collaboration dashboard
- Budget: $600K
- Priority: High
- Timeline: Q1 2025

Can you coordinate with Product Manager, Senior Architect, and CTO
to get this planned and approved?
```

**Claude will orchestrate:**
1. PM creates the requirement
2. Senior Architect reviews feasibility
3. Architect determines complexity is high
4. Escalates to CTO for approval
5. CTO sees $600K > $500K authority
6. CTO escalates to CEO (if you had CEO configured)
7. Reports the full decision chain

---

## Advanced: Add All 9 Agents

Once you've tested with 3 agents and everything works, add the rest:

### Full Configuration File

```json
{
  "mcpServers": {
    "echo-ceo": {
      "command": "/Users/pranav/Documents/echo/agents/ceo/ceo",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-cto": {
      "command": "/Users/pranav/Documents/echo/agents/cto/cto",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-chro": {
      "command": "/Users/pranav/Documents/echo/agents/chro/chro",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-operations-head": {
      "command": "/Users/pranav/Documents/echo/agents/operations_head/operations_head",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-product-manager": {
      "command": "/Users/pranav/Documents/echo/agents/product_manager/product_manager",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-senior-architect": {
      "command": "/Users/pranav/Documents/echo/agents/senior_architect/senior_architect",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-uiux-engineer": {
      "command": "/Users/pranav/Documents/echo/agents/uiux_engineer/uiux_engineer",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-senior-developer": {
      "command": "/Users/pranav/Documents/echo/agents/senior_developer/senior_developer",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-test-lead": {
      "command": "/Users/pranav/Documents/echo/agents/test_lead/test_lead",
      "env": {
        "DB_HOST": "localhost",
        "DB_NAME": "echo_org",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    }
  }
}
```

**Save, restart Claude Desktop, and you'll have all 9 agents available!**

---

## Understanding What Happens

### When You Ask Claude to Use an Agent Tool:

1. **Claude decides which tool to call** based on your request
2. **Claude Desktop starts the agent escript** as a subprocess
3. **Sends JSON-RPC initialize request** to the agent
4. **Agent starts up:**
   - Connects to PostgreSQL
   - Connects to Redis
   - Starts internal GenServers
5. **Agent responds with available tools**
6. **Claude Desktop calls the specific tool** with parameters
7. **Agent executes the tool:**
   - Runs business logic
   - Checks authority limits
   - May escalate if needed
   - Records decision in database
8. **Agent returns result** to Claude Desktop
9. **Agent process exits**
10. **Claude receives the result and responds to you**

**Key insight:** Each tool call starts a fresh agent process. Agents are stateless (state is in the database).

---

## Real Example Conversation

**You:**
```
I want to hire a senior engineer. Budget is $180K/year.
Can you help me with the ECHO hiring workflow?
```

**Claude:**
```
I'll help you coordinate the hiring process! Let me start with the CHRO
to create a hiring requisition.

[Calls: echo-chro.approve_hiring_request with budget $180K]

The CHRO has approved the hiring request. Since this is within their
$300K authority, no further escalation is needed.

The requisition has been created with:
- Role: Senior Engineer
- Budget: $180K/year
- Status: Approved
- Next steps: Job posting and candidate screening

Would you like me to check team capacity with the Operations Head, or
coordinate the technical interview process with the CTO?
```

**You:**
```
Yes, check team capacity first.
```

**Claude:**
```
[Calls: echo-operations-head.check_resource_availability]

The Operations Head reports:
- Current team capacity: 85%
- Availability: Can onboard new hire
- Recommended start date: Q1 2025
- No conflicts with other projects

The team has capacity for this hire. Would you like me to have the CTO
set up technical interviews?
```

---

## Viewing Agent Activity

### Check the Database

**See all decisions made:**
```bash
psql -h localhost -U postgres echo_org -c "
  SELECT from_role, to_role, subject, inserted_at
  FROM messages
  WHERE inserted_at > NOW() - INTERVAL '1 hour'
  ORDER BY inserted_at DESC
  LIMIT 20;
"
```

**See workflow executions:**
```bash
psql -h localhost -U postgres echo_org -c "
  SELECT workflow_name, status, current_step
  FROM workflow_executions
  WHERE inserted_at::date = CURRENT_DATE;
"
```

### Watch Redis Activity (Optional)

**In a separate terminal:**
```bash
redis-cli MONITOR
```

You'll see messages published when agents communicate.

---

## Troubleshooting

### Problem: Claude Desktop doesn't show the tools

**Check:**
1. Is the config file path correct?
   ```bash
   ls -la ~/.config/Claude/claude_desktop_config.json
   ```

2. Is the JSON valid?
   ```bash
   cat ~/.config/Claude/claude_desktop_config.json | python -m json.tool
   ```

3. Are the agent paths correct?
   ```bash
   ls -la /Users/pranav/Documents/echo/agents/ceo/ceo
   ```

4. Did you restart Claude Desktop?

### Problem: Agent tools error when called

**Check:**
1. Is PostgreSQL running?
   ```bash
   pg_isready -h localhost
   ```

2. Is Redis running?
   ```bash
   redis-cli ping
   ```

3. Does the database exist?
   ```bash
   psql -h localhost -U postgres -l | grep echo_org
   ```

4. Test the agent manually:
   ```bash
   cd /Users/pranav/Documents/echo/agents/ceo
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | ./ceo
   ```

### Problem: Slow performance

**This is normal!** Each tool call:
- Starts a new agent process (~300ms)
- Connects to PostgreSQL and Redis (~100ms)
- Executes the tool (~50ms)
- Total: ~450ms per tool call

For faster performance, you'd need daemon mode (agents always running).

---

## Advanced Usage

### Batch Operations

**You:**
```
I have 5 feature requests:
1. User authentication (Budget: $80K)
2. Dashboard analytics (Budget: $150K)
3. Mobile app (Budget: $300K)
4. API gateway (Budget: $200K)
5. Search functionality (Budget: $60K)

Can you have the Product Manager create requirements for all of them,
then get the Senior Architect to prioritize based on technical feasibility?
```

**Claude will:**
1. Call create_feature_requirement 5 times (one per feature)
2. Call review_technical_feasibility 5 times
3. Synthesize the architect's feedback
4. Provide a prioritized list with rationale

### Decision Tracking

**You:**
```
Show me all the decisions the CTO has made today.
```

**Claude will:**
1. Call review_engineering_metrics (which includes decision history)
2. Format and present the decisions
3. Show you approval/rejection patterns

### Escalation Testing

**You:**
```
I want to build a $2M infrastructure overhaul. Let's see the
escalation chain in action.
```

**Claude will:**
1. PM creates requirement ($2M)
2. Architect reviews (high complexity)
3. Escalates to CTO ($2M > $500K authority)
4. CTO escalates to CEO ($2M > $1M authority)
5. CEO makes final decision
6. Full audit trail in database

---

## What Makes This Powerful

### 1. Natural Language Interface
- No need to learn agent APIs
- Conversational workflow coordination
- Claude handles the orchestration logic

### 2. Real Business Logic
- Each agent has actual decision-making code
- Budget limits enforced
- Proper escalation chains
- Database-backed audit trail

### 3. Multi-Agent Coordination
- Agents don't talk to each other directly
- Claude coordinates based on your intent
- Flexible workflows (not rigid like our simulation)
- Adapts to your conversation flow

### 4. Incremental Adoption
- Start with 3 agents
- Add more as needed
- Remove agents you don't need
- Configure per-agent environment

### 5. Database Integration
- All decisions persisted
- Full audit trail
- Can query historical data
- Shared state across agents

---

## Best Practices

### 1. Start Small
- Test with 3 agents first
- Verify each agent works
- Then add the remaining 6

### 2. Use Descriptive Requests
```
❌ "Run feature dev"
✅ "I want to build a mobile dashboard. Can you coordinate with
    the Product Manager and Senior Architect to plan this?"
```

### 3. Review Agent Responses
- Agents return structured data
- Claude will show you what happened
- Check database for audit trail

### 4. Test Authority Limits
```
Try: $100K feature (PM approves)
Try: $400K feature (CTO approves)
Try: $800K feature (CEO required)
```

### 5. Monitor Database Growth
```bash
# Check database size
psql -h localhost -U postgres echo_org -c "
  SELECT pg_size_pretty(pg_database_size('echo_org'));
"
```

---

## Next Steps

### After Setup:

1. **Test basic coordination:**
   ```
   "Create a simple feature requirement using the Product Manager."
   ```

2. **Test escalation:**
   ```
   "Create a $600K feature and walk me through the approval chain."
   ```

3. **Test multi-agent workflows:**
   ```
   "Build a mobile app feature end-to-end with all relevant agents."
   ```

4. **Explore agent capabilities:**
   ```
   "What can the CTO agent do?"
   "Show me the Senior Architect's tools."
   ```

5. **Build real workflows:**
   - Use for actual project planning
   - Track real budget decisions
   - Document architectural choices
   - Coordinate team activities

---

## Summary

**To use ECHO agents in Claude Desktop:**

1. ✅ Verify all agents work (`./scripts/start_all_agents.sh`)
2. ✅ Create config file: `~/.config/Claude/claude_desktop_config.json`
3. ✅ Add 3 agents (PM, Architect, CTO) for testing
4. ✅ Restart Claude Desktop
5. ✅ Start conversation: "Show me the ECHO agent tools"
6. ✅ Coordinate workflows through natural conversation
7. ✅ Check database for audit trail
8. ✅ Add remaining 6 agents when ready

**You now have a real multi-agent organizational system running in Claude Desktop!** 🎉

---

## Example First Conversation

**Copy/paste this into Claude Desktop after setup:**

```
Hi! I just configured the ECHO organizational agents. Can you:

1. List all available ECHO agent tools
2. Help me create a feature requirement using the Product Manager
3. Have the Senior Architect review its technical feasibility
4. If it's complex, escalate to the CTO for approval
5. Show me what was recorded in the database

The feature is: "Real-time mobile dashboard with analytics"
Budget: $200K
Priority: High
```

**Claude will walk through the entire workflow and show you how the agents coordinate!**
# Claude Desktop Setup for ECHO Agents

This guide shows how to connect ECHO agents to Claude Desktop using MCP (Model Context Protocol).

## Prerequisites

1. **Claude Desktop** installed
2. **ECHO agents built** - Run `mix escript.build` in each agent directory if not already done
3. **PostgreSQL** running on localhost:5432 with `echo_org_dev` database
4. **Redis** running on localhost:6379

## Quick Start - Core Leadership Team

Connect the three core agents (CEO, CTO, Product Manager) to Claude Desktop:

### 1. Locate Your Configuration File

**macOS:**
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

**Linux:**
```
~/.config/Claude/claude_desktop_config.json
```

**Windows:**
```
%APPDATA%\Claude\claude_desktop_config.json
```

### 2. Add Agent Configuration

Create or edit the configuration file with this content:

```json
{
  "mcpServers": {
    "echo-ceo": {
      "command": "/Users/pranav/Documents/echo/agents/ceo/ceo",
      "env": {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "echo_org_dev",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-cto": {
      "command": "/Users/pranav/Documents/echo/agents/cto/cto",
      "env": {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "echo_org_dev",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-product-manager": {
      "command": "/Users/pranav/Documents/echo/agents/product_manager/product_manager",
      "env": {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "echo_org_dev",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    }
  }
}
```

**IMPORTANT:** Replace `/Users/pranav/Documents/echo` with the absolute path to your ECHO project directory.

### 3. Restart Claude Desktop

After saving the configuration, completely quit and restart Claude Desktop for changes to take effect.

### 4. Verify Agents Are Connected

In Claude Desktop, start a new conversation and type:

```
List all available tools from the CEO agent
```

You should see tools like:
- `approve_strategic_initiative`
- `allocate_budget`
- `review_organizational_health`
- `escalate_to_human`

## Testing the Agents

### Test 1: CEO Autonomous Decision

Try this in Claude Desktop:

```
Use the CEO agent to approve a strategic initiative called "AI Research Lab"
with a budget of $500,000 and expected outcome of "Advanced AI capabilities"
```

The CEO should autonomously approve this (under $1M authority limit).

### Test 2: CTO Technical Review

```
Use the CTO agent to review a system design for "Microservices Migration"
with components: ["API Gateway", "Service Mesh", "Event Bus"]
```

The CTO should provide architectural feedback.

### Test 3: Product Manager Feature Prioritization

```
Use the Product Manager to prioritize these features:
- User authentication (impact: high, effort: medium)
- Dark mode (impact: medium, effort: low)
- Analytics dashboard (impact: high, effort: high)
```

The PM should rank features by ROI.

### Test 4: Multi-Agent Collaboration

```
I want to launch a new product feature.
1. Ask the Product Manager to define the feature requirements
2. Have the CTO review technical feasibility
3. Get CEO approval for the budget
```

This tests inter-agent communication through the message bus.

## Monitoring Agent Activity

While testing, you can monitor agent health and messages using the monitoring script:

```bash
# In your ECHO project directory
./echo.sh summary

# Watch agent heartbeats
watch -n 2 './echo.sh agents'

# Monitor message queue
./echo.sh messages
```

## Adding More Agents

To add the remaining agents (CHRO, Operations Head, Senior Architect, etc.), add more entries to the `mcpServers` section:

```json
{
  "mcpServers": {
    "echo-ceo": { ... },
    "echo-cto": { ... },
    "echo-product-manager": { ... },
    "echo-chro": {
      "command": "/path/to/echo/agents/chro/chro",
      "env": { ... }
    },
    "echo-operations-head": {
      "command": "/path/to/echo/agents/operations_head/operations_head",
      "env": { ... }
    },
    "echo-senior-architect": {
      "command": "/path/to/echo/agents/senior_architect/senior_architect",
      "env": { ... }
    },
    "echo-ui-ux-engineer": {
      "command": "/path/to/echo/agents/ui_ux_engineer/ui_ux_engineer",
      "env": { ... }
    },
    "echo-senior-developer": {
      "command": "/path/to/echo/agents/senior_developer/senior_developer",
      "env": { ... }
    },
    "echo-test-lead": {
      "command": "/path/to/echo/agents/test_lead/test_lead",
      "env": { ... }
    }
  }
}
```

## Environment Variables

You can customize the configuration by changing these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `echo_org_dev` | Database name |
| `DB_USER` | `postgres` | Database user |
| `DB_PASSWORD` | `postgres` | Database password |
| `REDIS_HOST` | `localhost` | Redis host |
| `REDIS_PORT` | `6379` | Redis port |

## Advanced Configuration

### Using Production Database

```json
{
  "mcpServers": {
    "echo-ceo": {
      "command": "/path/to/echo/agents/ceo/ceo",
      "env": {
        "DB_HOST": "prod.example.com",
        "DB_NAME": "echo_org",
        "DB_USER": "echo_user",
        "DB_PASSWORD": "secure_password",
        "REDIS_HOST": "cache.example.com"
      }
    }
  }
}
```

### Custom Agent Authority Limits

```json
{
  "mcpServers": {
    "echo-ceo": {
      "command": "/path/to/echo/agents/ceo/ceo",
      "env": {
        "AUTONOMOUS_BUDGET_LIMIT": "5000000",
        "DB_HOST": "localhost",
        ...
      }
    }
  }
}
```

## Troubleshooting

### Agent Not Showing Up in Claude Desktop

**Problem:** Agent doesn't appear in available tools

**Solutions:**
1. Verify the executable path is correct and absolute (not relative)
2. Check executable has execute permissions: `chmod +x /path/to/agent`
3. Completely quit and restart Claude Desktop (not just close window)
4. Check Claude Desktop logs for errors

**macOS Log Location:**
```
~/Library/Logs/Claude/mcp*.log
```

### Agent Crashes on Startup

**Problem:** Agent starts then immediately exits

**Solutions:**
1. Test the agent directly in terminal:
   ```bash
   cd /path/to/echo/agents/ceo
   ./ceo
   ```
2. Check database is running: `psql -h localhost -U postgres -d echo_org_dev`
3. Check Redis is running: `redis-cli ping`
4. Verify migrations are up to date: `cd shared && mix ecto.migrate`

### "Database Connection Error"

**Problem:** Agent can't connect to PostgreSQL

**Solutions:**
1. Ensure PostgreSQL is running:
   ```bash
   # macOS with Homebrew
   brew services start postgresql

   # Linux with systemd
   sudo systemctl start postgresql
   ```
2. Verify database exists:
   ```bash
   psql -h localhost -U postgres -l | grep echo_org_dev
   ```
3. Create database if missing:
   ```bash
   cd /path/to/echo/shared
   mix ecto.create
   mix ecto.migrate
   ```

### "Redis Connection Refused"

**Problem:** Agent can't connect to Redis

**Solutions:**
1. Start Redis:
   ```bash
   # macOS with Homebrew
   brew services start redis

   # Linux
   sudo systemctl start redis

   # Manual
   redis-server --daemonize yes
   ```
2. Test connection: `redis-cli ping` (should return `PONG`)

### Agent Tools Not Working

**Problem:** Agent connected but tools fail to execute

**Solutions:**
1. Check agent health:
   ```bash
   ./echo.sh agents
   ```
2. Check for errors in database:
   ```sql
   SELECT * FROM messages WHERE processing_error IS NOT NULL ORDER BY inserted_at DESC LIMIT 10;
   ```
3. View agent logs (they output to stderr):
   ```bash
   # Run agent manually to see logs
   cd /path/to/echo/agents/ceo
   ./ceo 2>ceo_errors.log
   ```

## Example Multi-Agent Workflow

Here's a complete example workflow you can try in Claude Desktop:

```
I want to build a new feature: "Customer Analytics Dashboard"

Please coordinate with the ECHO team:

1. Product Manager: Define feature requirements and prioritize
2. Senior Architect: Design the system architecture
3. CTO: Review and approve the technical approach
4. UI/UX Engineer: Create interface mockups
5. CEO: Approve the budget allocation
6. Test Lead: Define testing strategy

Use the agents to work through this workflow and show me the decisions and communications.
```

This will demonstrate:
- Multi-agent coordination
- Inter-agent messaging
- Decision modes (autonomous, collaborative, hierarchical)
- Human-in-the-loop escalation (if budget exceeds limits)

## Security Considerations

### Do NOT Commit Configuration

Add this to your `.gitignore`:

```
# Claude Desktop config (contains credentials)
claude_desktop_config.json
**/claude_desktop_config.json
```

### Use Environment Variables for Secrets

Instead of hardcoding passwords, reference environment variables:

```json
{
  "mcpServers": {
    "echo-ceo": {
      "command": "/path/to/echo/agents/ceo/ceo",
      "env": {
        "DB_PASSWORD": "${DB_PASSWORD}",
        "DB_HOST": "${DB_HOST:-localhost}"
      }
    }
  }
}
```

Then set them before starting Claude Desktop:

```bash
export DB_PASSWORD="your_secure_password"
export DB_HOST="your_db_host"
open -a "Claude"
```

## Next Steps

1. **Try the Demo Workflow** - Test the multi-agent example above
2. **Monitor System Health** - Use `./echo.sh summary` to watch agent activity
3. **Add More Agents** - Connect the remaining 6 agents
4. **Create Custom Workflows** - Define your own multi-agent workflows in `workflows/examples/`
5. **Explore Decision Modes** - Try autonomous, collaborative, hierarchical, and human-in-the-loop decisions

## Related Documentation

- `AGENT_INTEGRATION_GUIDE.md` - How agents are implemented internally
- `ECHO_SH_README.md` - Comprehensive monitoring script documentation
- `DISTRIBUTED_SYSTEMS_IMPROVEMENTS.md` - Architecture and distributed systems patterns
- `ECHO_ARCHITECTURE.md` - Complete system design
