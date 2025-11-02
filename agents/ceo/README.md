# CEO Agent - Chief Executive Officer

**Status:** Phase 2 - Reference Implementation
**Role:** Strategic Leadership & Organizational Oversight
**Version:** 0.1.0

## Overview

The CEO agent is the highest authority in the ECHO organizational model, responsible for strategic planning, budget allocation, crisis management, and final decision-making. This implementation serves as a reference for all other ECHO agents.

## Responsibilities

### Strategic Leadership
- Set organizational vision and direction
- Approve major strategic initiatives
- Allocate budgets to departments and projects
- Make final decisions on organizational structure

### Decision Authority
The CEO has autonomous authority over:
- Strategic planning decisions (confidence > 70%)
- Budget allocations up to $1,000,000
- C-suite hiring and performance management
- Organizational crisis response

### Escalation & Oversight
- Review escalated decisions from other agents
- Override decisions when necessary (with rationale)
- Monitor organizational health and agent performance
- Escalate critical decisions to human judgment

## MCP Tools

The CEO provides 6 tools to Claude Desktop:

### 1. approve_strategic_initiative
Approve strategic proposals from other agents.

**Arguments:**
- `initiative_id` (required): Decision ID to approve
- `rationale` (required): CEO's approval rationale
- `budget_allocated` (optional): Budget amount in dollars
- `conditions` (optional): Approval conditions

### 2. allocate_budget
Allocate budget to departments or projects.

**Arguments:**
- `recipient_role` (required): Role receiving budget
- `amount` (required): Budget amount in dollars
- `purpose` (required): Purpose of allocation
- `duration` (optional): Budget duration (e.g., "Q1 2025")

**Constraints:**
- Autonomous limit: $1,000,000
- Above limit requires board approval (escalation)

### 3. escalate_to_human
Escalate decisions requiring human judgment.

**Arguments:**
- `decision_id` (required): Decision ID to escalate
- `reason` (required): Why human judgment is needed
- `urgency` (required): low | medium | high | critical
- `context` (optional): Additional context

### 4. review_organizational_health
Get comprehensive status of all agents and systems.

**Arguments:**
- `include_metrics` (optional): Include performance metrics (default: true)
- `time_range` (optional): "24h" | "7d" | "30d" (default: "24h")

**Returns:**
- Agent health status (running/stopped/error)
- Recent decisions and completion rates
- Organizational metrics and trends
- Overall health assessment

### 5. initiate_decision
Start a new organizational decision process.

**Arguments:**
- `decision_type` (required): Type of decision
- `mode` (required): autonomous | collaborative | hierarchical | human
- `participants` (optional): Roles to include (for collaborative)
- `context` (required): Decision context and details
- `deadline` (optional): ISO 8601 deadline

### 6. override_decision
Override a decision made by a subordinate agent.

**Arguments:**
- `decision_id` (required): Decision ID to override
- `override_rationale` (required): Detailed rationale
- `new_outcome` (required): New decision outcome
- `notify_agents` (optional): Roles to notify

**Warning:** Use sparingly. Overriding decisions undermines agent autonomy and should only be done when necessary.

## Architecture

### Components

**Ceo Module (lib/ceo.ex)**
- Main MCP server implementation
- Uses `EchoShared.MCP.Server` behavior
- Implements 6 MCP tools
- Handles tool execution and database operations

**Ceo.DecisionEngine (lib/ceo/decision_engine.ex)**
- Autonomous decision-making logic
- Confidence calculation
- Authority validation
- Escalation threshold enforcement

**Ceo.MessageHandler (lib/ceo/message_handler.ex)**
- Redis pub/sub message handling
- Processes direct messages, broadcasts, escalations
- Monitors decision events
- Logs for CEO awareness

**Ceo.Application (lib/ceo/application.ex)**
- OTP supervisor
- Starts shared infrastructure (DB, Redis)
- Starts CEO-specific services

### Supervision Tree

```
Ceo.Supervisor (one_for_one)
├── EchoShared.Repo (database connection pool)
├── Redix (Redis commands)
├── Redix.PubSub (Redis pub/sub)
├── Ceo.DecisionEngine (decision logic)
└── Ceo.MessageHandler (message processing)
```

### Decision-Making Flow

1. **Tool Call Received** (via MCP protocol)
2. **Validate Arguments** (required fields, types)
3. **Check Authority** (budget limits, decision type)
4. **Calculate Confidence** (DecisionEngine)
5. **Execute or Escalate**:
   - High confidence: Execute autonomously
   - Low confidence: Escalate to human
6. **Update Database** (record decision, outcome)
7. **Notify Agents** (via MessageBus)
8. **Return Result** (to Claude Desktop)

## Configuration

### Environment Variables

**Database:**
- `DB_HOST` - PostgreSQL host (default: localhost)
- `DB_USER` - Database user (default: postgres)
- `DB_PASSWORD` - Database password
- `DB_PORT` - Database port (default: 5432)

**Redis:**
- `REDIS_HOST` - Redis host (default: localhost)
- `REDIS_PORT` - Redis port (default: 6379)

**CEO Settings:**
- `CEO_AUTONOMOUS_MODE` - Enable autonomous decisions (default: true)
- `CEO_BUDGET_LIMIT` - Autonomous budget limit (default: 1000000)
- `CEO_ESCALATION_THRESHOLD` - Confidence threshold (default: 0.7)

### Application Config

**config/config.exs:**
```elixir
config :ceo,
  role: :ceo,
  decision_authority: [
    :strategic_planning,
    :budget_allocation,
    :c_suite_hiring,
    :company_direction,
    :crisis_management
  ],
  escalation_threshold: 0.7,
  autonomous_budget_limit: 1_000_000
```

## Development

### Setup

```bash
cd agents/ceo

# Install dependencies
mix deps.get

# Compile
mix compile

# Build escript
mix escript.build

# Run in development mode
./dev.sh
```

### Testing with Claude Desktop

Add to Claude Desktop MCP config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "echo-ceo": {
      "command": "/Users/pranav/Documents/echo/agents/ceo/ceo",
      "args": []
    }
  }
}
```

Restart Claude Desktop to load the CEO agent.

### Example Usage

**1. Review Organizational Health:**
```
Use the review_organizational_health tool to get current status.
```

**2. Approve a Strategic Initiative:**
```
Approve initiative dec_abc123 with rationale "Strong ROI projection and team alignment" and allocate $500,000 budget.
```

**3. Allocate Budget:**
```
Allocate $250,000 to the CTO for Q1 2025 infrastructure improvements.
```

**4. Escalate Critical Decision:**
```
Escalate decision dec_xyz789 to human judgment because it involves significant organizational restructuring with high uncertainty.
```

## Integration with Other Agents

### Message Bus Channels

**Subscribes to:**
- `messages:ceo` - Direct messages to CEO
- `messages:all` - Organization-wide broadcasts
- `messages:leadership` - C-suite communications
- `decisions:new` - New decision notifications
- `decisions:escalated` - Escalation notifications

**Publishes to:**
- `messages:{role}` - Direct messages to specific agents
- `messages:all` - Organization-wide announcements
- `decisions:completed` - Decision finalization
- `agents:heartbeat` - Health status

### Database Schema Usage

**EchoShared.Schemas.Decision:**
- Creates decisions via `initiate_decision`
- Updates decisions via approval/override tools
- Queries decisions for health reports

**EchoShared.Schemas.AgentStatus:**
- Reads status of all agents
- Used in `review_organizational_health`

**EchoShared.Schemas.Message:**
- Stores audit trail of communications
- Used for compliance and review

## Design Patterns

### 1. Autonomous Decision-Making
The CEO evaluates confidence before making decisions:
- High confidence (>70%): Decide autonomously
- Low confidence (<70%): Escalate to human

### 2. Authority Boundaries
Budget limits and decision types define CEO authority:
- Within authority: Execute immediately
- Outside authority: Request board approval

### 3. Graceful Escalation
When uncertain, escalate with context:
- Clear rationale for escalation
- Urgency level specified
- All relevant context included

### 4. Audit Trail
All decisions and communications logged:
- Database records for compliance
- Message bus events for real-time monitoring
- Metadata includes timestamps, rationale, participants

## Next Steps

### Phase 3: Implement Remaining Agents
Use CEO as reference implementation for:
- CTO (Week 2-3)
- CHRO (Week 3)
- Operations Head (Week 3-4)
- Product Manager (Week 4)
- Senior Architect (Week 4)
- UI/UX Engineer (Week 4)
- Senior Developer (Week 4)
- Test Lead (Week 4)

### Phase 4: Workflows & Integration
- Multi-agent decision workflows
- Real-time collaboration patterns
- Crisis response procedures

### Phase 5: Production Deployment
- Docker containers
- Kubernetes orchestration
- Monitoring and observability

## Contributing

When extending the CEO agent:
1. Add new tools to `tools/0` function
2. Implement tool logic in `execute_tool/2`
3. Update documentation
4. Add tests
5. Follow patterns established in this reference implementation

## License

MIT License - see ../../LICENSE
