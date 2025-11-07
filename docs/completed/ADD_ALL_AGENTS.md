# Add All 9 ECHO Agents to Claude Desktop

## Quick Steps

### Option 1: Replace Config (Easiest)

1. **Copy the complete configuration:**
   ```bash
   cp claude_desktop_config_all_agents.json ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

2. **Restart Claude Desktop** (completely quit and reopen)

3. **Verify all agents are connected:**
   In Claude Desktop, ask:
   ```
   List all available MCP tools and group them by server
   ```

You should see tools from all 9 agents!

---

### Option 2: Manual Edit (If you have other MCP servers)

1. **Open your Claude Desktop config:**
   ```bash
   open ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

2. **Add these 6 missing agents** to your existing config:

```json
{
  "mcpServers": {
    "echo-ceo": { ... existing ... },
    "echo-cto": { ... existing ... },
    "echo-product-manager": { ... existing ... },

    "echo-chro": {
      "command": "/Users/pranav/Documents/echo/agents/chro/chro",
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
    "echo-operations-head": {
      "command": "/Users/pranav/Documents/echo/agents/operations_head/operations_head",
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
    "echo-senior-architect": {
      "command": "/Users/pranav/Documents/echo/agents/senior_architect/senior_architect",
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
    "echo-ui-ux-engineer": {
      "command": "/Users/pranav/Documents/echo/agents/uiux_engineer/uiux_engineer",
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
    "echo-senior-developer": {
      "command": "/Users/pranav/Documents/echo/agents/senior_developer/senior_developer",
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
    "echo-test-lead": {
      "command": "/Users/pranav/Documents/echo/agents/test_lead/test_lead",
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

3. **Save and restart Claude Desktop**

---

## Verify All 9 Agents

After restarting Claude Desktop, test each agent:

### Test 1: List All Tools
```
Show me a summary of all available ECHO agent tools
```

### Test 2: Test Each Agent

**CEO:**
```
Use the CEO agent to review organizational health
```

**CTO:**
```
Use the CTO agent to review a system design for "API Gateway Architecture"
```

**CHRO:**
```
Use the CHRO agent to review the hiring pipeline status
```

**Operations Head:**
```
Use the Operations Head to check infrastructure health
```

**Product Manager:**
```
Use the Product Manager to prioritize these features:
- User authentication (high impact, medium effort)
- Dark mode (medium impact, low effort)
```

**Senior Architect:**
```
Use the Senior Architect to design a microservices architecture
```

**UI/UX Engineer:**
```
Use the UI/UX Engineer to review the user onboarding flow
```

**Senior Developer:**
```
Use the Senior Developer to review code quality standards
```

**Test Lead:**
```
Use the Test Lead to create a testing strategy for the new feature
```

---

## Full Agent List

| Agent | Server Name | Executable |
|-------|-------------|-----------|
| ✅ CEO | `echo-ceo` | `agents/ceo/ceo` |
| ✅ CTO | `echo-cto` | `agents/cto/cto` |
| ✅ CHRO | `echo-chro` | `agents/chro/chro` |
| ✅ Operations Head | `echo-operations-head` | `agents/operations_head/operations_head` |
| ✅ Product Manager | `echo-product-manager` | `agents/product_manager/product_manager` |
| ✅ Senior Architect | `echo-senior-architect` | `agents/senior_architect/senior_architect` |
| ✅ UI/UX Engineer | `echo-ui-ux-engineer` | `agents/uiux_engineer/uiux_engineer` |
| ✅ Senior Developer | `echo-senior-developer` | `agents/senior_developer/senior_developer` |
| ✅ Test Lead | `echo-test-lead` | `agents/test_lead/test_lead` |

---

## Troubleshooting

### "Agent not showing in Claude Desktop"

1. **Check the path is absolute:**
   ```bash
   ls -l /Users/pranav/Documents/echo/agents/chro/chro
   ```
   Should show the executable exists

2. **Verify config syntax:**
   ```bash
   cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq '.'
   ```
   Should parse without errors

3. **Completely restart Claude Desktop:**
   - Cmd+Q to quit (not just close window)
   - Reopen from Applications

4. **Check Claude Desktop logs:**
   ```bash
   tail -f ~/Library/Logs/Claude/mcp*.log
   ```

### "Too many agents slow?"

If 9 agents feels like too many, you can start with subsets:

**Leadership Team (3):**
- CEO, CTO, CHRO

**Technical Team (4):**
- CTO, Senior Architect, Senior Developer, Test Lead

**Product Team (3):**
- Product Manager, UI/UX Engineer, Senior Developer

Just comment out the agents you don't need:

```json
{
  "mcpServers": {
    "echo-ceo": { ... },
    // "echo-chro": { ... },  /* Commented out */
    "echo-cto": { ... }
  }
}
```

---

## Example Multi-Agent Workflow

Once all agents are connected, try this comprehensive workflow:

```
I want to build a new feature: "Real-time Collaboration Board"

Please coordinate with the ECHO team:

1. Product Manager: Define requirements and business value
2. UI/UX Engineer: Create interface mockups
3. Senior Architect: Design the system architecture
4. CTO: Review and approve the technical approach
5. Senior Developer: Estimate implementation complexity
6. Test Lead: Define testing strategy
7. Operations Head: Review infrastructure requirements
8. CHRO: Assess team capacity and hiring needs
9. CEO: Approve final budget and timeline

Work through this systematically, showing each agent's contribution.
```

This demonstrates the full power of the ECHO multi-agent system!

---

## Configuration File Location

**Current config:** `~/Library/Application Support/Claude/claude_desktop_config.json`

**Template with all 9 agents:** `claude_desktop_config_all_agents.json` (in this directory)

**Backup your config before replacing:**
```bash
cp ~/Library/Application\ Support/Claude/claude_desktop_config.json \
   ~/Library/Application\ Support/Claude/claude_desktop_config.json.backup
```

---

## Summary

1. Copy `claude_desktop_config_all_agents.json` to Claude Desktop config location
2. Restart Claude Desktop
3. Test: "List all available MCP tools"
4. Should see tools from all 9 agents!

**Enjoy your complete ECHO organization!** 🎉
