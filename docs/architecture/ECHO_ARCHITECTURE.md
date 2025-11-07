╔══════════════════════════════════════════════════════════════════════════╗
║  ECHO STANDALONE REPOSITORY - MCP ARCHITECTURE DESIGN                    ║
║  Designed by: Senior Architect Agent                                     ║
║  Date: 2025-11-03                                                        ║
╚══════════════════════════════════════════════════════════════════════════╝

## 1. SYSTEM ARCHITECTURE

### High-Level Architecture

┌─────────────────────────────────────────────────────────────────────┐
│  MCP Client Layer (Claude Desktop, Cline, etc.)                     │
└────────────┬────────────────────────────────────────────────────────┘
             │
             │ JSON-RPC 2.0 over stdio
             │
    ┌────────┴─────────────────────────────────────────────────┐
    │                                                           │
    ▼                                                           ▼
┌─────────────────┐                                    ┌──────────────────┐
│  Agent MCP      │                                    │  Agent MCP       │
│  Servers (9)    │◄───────── Redis Pub/Sub ─────────►│  Servers (cont.) │
│                 │                                    │                  │
│  • CEO          │                                    │  • Architect     │
│  • CTO          │                                    │  • UI/UX         │
│  • CHRO         │                                    │  • Developer     │
│  • Ops Head     │                                    │  • Test Lead     │
│  • Prod Mgr     │                                    │                  │
└────────┬────────┘                                    └────────┬─────────┘
         │                                                      │
         │                                                      │
         └──────────────────┬───────────────────────────────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │  Shared Storage      │
                │                      │
                │  • PostgreSQL        │
                │    - Decisions       │
                │    - Messages        │
                │    - Memories        │
                │                      │
                │  • Redis             │
                │    - Message Bus     │
                │    - Pub/Sub         │
                │    - Agent Status    │
                └──────────────────────┘

### Component Breakdown

**MCP Server Layer (9 Independent Processes)**
- Each agent runs as standalone Elixir/OTP application
- Implements MCP protocol (JSON-RPC 2.0 over stdio)
- Exposes role-specific tools and resources
- Stateless (state in PostgreSQL)
- Horizontally scalable

**Message Bus (Redis)**
- Pub/Sub channels per agent
- Broadcast channels for all-hands messages
- Decision coordination channel
- Real-time event streaming
- TTL-based message expiry

**Shared Storage (PostgreSQL)**
- ACID transactions for decisions
- Full audit trail
- Cross-agent state synchronization
- Ecto for schema validation
- Migrations for versioning

## 2. MCP TOOL DEFINITIONS

### CEO MCP Server Tools

1. **approve_strategic_initiative**
   - Input: {initiative: string, business_value: string, budget: number}
   - Output: {approved: boolean, decision_id: string, rationale: string}
   - Authority: Autonomous up to $1M, else requires board approval

2. **allocate_budget**
   - Input: {amount: number, department: string, justification: string}
   - Output: {allocated: boolean, tracking_id: string}
   - Authority: Full control over approved budget

3. **escalate_to_board**
   - Input: {decision_id: string, urgency: enum}
   - Output: {escalation_id: string, human_approval_required: true}

4. **review_organizational_health**
   - Input: {metrics: [string]}
   - Output: {health_score: number, issues: [string], recommendations: [string]}

### CTO MCP Server Tools

1. **review_architecture**
   - Input: {design: object, components: [string], scalability: string}
   - Output: {approved: boolean, feedback: string, modifications: [string]}

2. **select_technology**
   - Input: {options: [string], criteria: object, timeline: string}
   - Output: {selected: string, rationale: string, migration_plan: string}

3. **assess_technical_debt**
   - Input: {codebase_metrics: object}
   - Output: {debt_score: number, priority_fixes: [string]}

4. **approve_deployment**
   - Input: {release: string, environments: [string]}
   - Output: {approved: boolean, deployment_plan: object}

### Product Manager MCP Server Tools

1. **define_feature**
   - Input: {name: string, user_stories: [string], business_value: string}
   - Output: {feature_id: string, requirements: object, priority: enum}

2. **prioritize_backlog**
   - Input: {items: [object], constraints: object}
   - Output: {prioritized_backlog: [object], rationale: string}

3. **gather_requirements**
   - Input: {feature: string, stakeholders: [string]}
   - Output: {requirements_doc: object, acceptance_criteria: [string]}

### Senior Architect MCP Server Tools

1. **design_system**
   - Input: {requirements: object, constraints: object}
   - Output: {architecture: object, components: [object], data_flow: string}

2. **evaluate_technology**
   - Input: {technology: string, use_case: string}
   - Output: {score: number, pros: [string], cons: [string], recommendation: string}

3. **create_technical_spec**
   - Input: {feature: string, architecture: object}
   - Output: {spec_document: object, implementation_guide: string}

... (similar tool definitions for remaining 5 agents)

## 3. DATABASE SCHEMA

```sql
-- Organizational Decisions
CREATE TABLE decisions (
  id UUID PRIMARY KEY,
  decision_type VARCHAR(100) NOT NULL,
  initiator_role VARCHAR(50) NOT NULL,
  participants JSONB,
  mode VARCHAR(50) NOT NULL, -- autonomous, collaborative, hierarchical, human
  context JSONB NOT NULL,
  status VARCHAR(50) NOT NULL, -- pending, approved, rejected, escalated
  consensus_score FLOAT,
  outcome JSONB,
  created_at TIMESTAMP NOT NULL,
  completed_at TIMESTAMP,
  
  INDEX idx_decisions_role (initiator_role),
  INDEX idx_decisions_status (status),
  INDEX idx_decisions_type (decision_type)
);

-- Inter-Agent Messages
CREATE TABLE messages (
  id BIGSERIAL PRIMARY KEY,
  from_role VARCHAR(50) NOT NULL,
  to_role VARCHAR(50) NOT NULL,
  type VARCHAR(50) NOT NULL, -- request, response, notification, escalation
  subject VARCHAR(255) NOT NULL,
  content JSONB NOT NULL,
  metadata JSONB,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL,
  
  INDEX idx_messages_to (to_role, created_at),
  INDEX idx_messages_from (from_role, created_at),
  INDEX idx_messages_unread (to_role, read)
);

-- Organizational Memory
CREATE TABLE memories (
  id UUID PRIMARY KEY,
  key VARCHAR(255) UNIQUE NOT NULL,
  content TEXT NOT NULL,
  tags TEXT[] NOT NULL,
  metadata JSONB,
  created_by_role VARCHAR(50),
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  
  INDEX idx_memories_key (key),
  INDEX idx_memories_tags (tags) USING GIN,
  INDEX idx_memories_role (created_by_role)
);

-- Collaborative Decision Votes
CREATE TABLE decision_votes (
  id BIGSERIAL PRIMARY KEY,
  decision_id UUID REFERENCES decisions(id),
  voter_role VARCHAR(50) NOT NULL,
  vote VARCHAR(20) NOT NULL, -- approve, reject, abstain
  rationale TEXT,
  confidence FLOAT NOT NULL,
  voted_at TIMESTAMP NOT NULL,
  
  UNIQUE(decision_id, voter_role),
  INDEX idx_votes_decision (decision_id)
);

-- Agent Health Status
CREATE TABLE agent_status (
  role VARCHAR(50) PRIMARY KEY,
  status VARCHAR(20) NOT NULL, -- running, stopped, error
  last_heartbeat TIMESTAMP NOT NULL,
  version VARCHAR(20),
  capabilities JSONB,
  metadata JSONB,
  
  INDEX idx_agent_status_heartbeat (last_heartbeat)
);
```

## 4. MESSAGE BUS PROTOCOL

### Redis Pub/Sub Channels

```
# Per-Agent Channels
messages:ceo              # Private messages to CEO
messages:cto              # Private messages to CTO
messages:chro
messages:operations_head
messages:product_manager
messages:senior_architect
messages:uiux_engineer
messages:senior_developer
messages:test_lead

# Broadcast Channels
messages:all              # All-hands announcements
messages:leadership       # CEO, CTO, CHRO, Ops

# Decision Coordination
decisions:new             # New decision initiated
decisions:vote_required   # Vote needed from participant
decisions:completed       # Decision finalized
decisions:escalated       # Escalated to higher authority

# System Channels
agents:heartbeat          # Agent health checks
agents:status             # Agent status updates
```

### Message Format (Redis)

```json
{
  "id": "msg_abc123",
  "from": "ceo",
  "to": "cto",
  "type": "request",
  "subject": "Q3 Technology Strategy Review",
  "content": {
    "question": "What are our top 3 priorities?",
    "deadline": "2025-11-10",
    "context": "Board meeting preparation"
  },
  "metadata": {
    "priority": "high",
    "thread_id": "thread_xyz",
    "timestamp": "2025-11-03T12:00:00Z"
  }
}
```

## 5. DEPLOYMENT ARCHITECTURE

### Docker Deployment

```
docker-compose.yml:

services:
  # Infrastructure
  postgres:
    image: postgres:16-alpine
    volumes: [./data/postgres:/var/lib/postgresql/data]
    environment:
      POSTGRES_DB: echo_org
      POSTGRES_USER: echo
      POSTGRES_PASSWORD: ${DB_PASSWORD}
  
  redis:
    image: redis:7-alpine
    volumes: [./data/redis:/data]
  
  # Agent MCP Servers
  echo-ceo:
    build: ./agents/ceo
    depends_on: [postgres, redis]
    environment:
      ROLE: ceo
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
  
  echo-cto:
    build: ./agents/cto
    depends_on: [postgres, redis]
    environment:
      ROLE: cto
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
  
  # ... (7 more agent services)
```

### Kubernetes Deployment (Production)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: echo-org

---
# StatefulSet for each agent
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: echo-ceo
  namespace: echo-org
spec:
  serviceName: echo-ceo
  replicas: 1
  selector:
    matchLabels:
      app: echo-ceo
      role: ceo
  template:
    metadata:
      labels:
        app: echo-ceo
        role: ceo
    spec:
      containers:
      - name: ceo
        image: ghcr.io/pranavj17/echo-ceo:latest
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: echo-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: echo-secrets
              key: redis-url
```

## 6. REPOSITORY STRUCTURE

```
echo/
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Tests + builds
│       ├── docker-publish.yml     # Push to GHCR
│       └── release.yml            # GitHub releases
│
├── agents/
│   ├── ceo/
│   │   ├── Dockerfile
│   │   ├── mix.exs
│   │   ├── lib/
│   │   │   └── echo/
│   │   │       ├── mcp_server.ex
│   │   │       ├── tools.ex
│   │   │       └── decision_logic.ex
│   │   └── config/
│   │
│   ├── cto/
│   ├── chro/
│   ├── operations_head/
│   ├── product_manager/
│   ├── senior_architect/
│   ├── uiux_engineer/
│   ├── senior_developer/
│   └── test_lead/
│
├── shared/
│   ├── lib/
│   │   └── echo/
│   │       ├── storage.ex         # PostgreSQL interface
│   │       ├── message_bus.ex     # Redis pub/sub
│   │       ├── schemas/
│   │       │   ├── decision.ex
│   │       │   ├── message.ex
│   │       │   └── memory.ex
│   │       └── mcp/
│   │           ├── protocol.ex    # MCP JSON-RPC
│   │           └── base_server.ex
│   └── priv/
│       └── repo/
│           └── migrations/
│
├── workflows/
│   ├── feature_development.ex
│   ├── incident_response.ex
│   └── strategic_planning.ex
│
├── docker-compose.yml
├── docker-compose.prod.yml
├── k8s/
│   ├── namespace.yml
│   ├── postgres.yml
│   ├── redis.yml
│   └── agents/
│       ├── ceo.yml
│       └── ...
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── MCP_TOOLS.md
│   ├── DEPLOYMENT.md
│   └── DEVELOPMENT.md
│
├── examples/
│   ├── claude_desktop_config.json
│   ├── workflows/
│   └── scripts/
│
├── README.md
├── LICENSE
└── .gitignore
```

## 7. TECHNOLOGY DECISIONS

### Core Stack
- **Language**: Elixir 1.18
- **Runtime**: Erlang/OTP 27
- **Database**: PostgreSQL 16
- **Message Bus**: Redis 7
- **Container**: Docker + Docker Compose
- **Orchestration**: Kubernetes (optional)

### Key Libraries
- **Phoenix**: Web framework (if HTTP mode needed)
- **Ecto**: Database ORM
- **Redix**: Redis client
- **Jason**: JSON encoding/decoding
- **Telemetry**: Metrics and monitoring

### Rationale
1. **Elixir/OTP**: Perfect actor model for agents
2. **PostgreSQL**: ACID guarantees for decisions
3. **Redis**: Low-latency pub/sub for real-time coordination
4. **Docker**: Consistent deployment across environments
5. **MCP Protocol**: Standard interface for AI agents

## 8. IMPLEMENTATION PHASES

### Phase 1: Foundation (Week 1)
- [ ] Shared library with MCP protocol implementation
- [ ] Database schemas and migrations
- [ ] Redis message bus implementation
- [ ] Base MCP server behavior
- [ ] CEO agent (reference implementation)

### Phase 2: Core Agents (Week 2)
- [ ] Implement remaining 8 agent MCP servers
- [ ] Tool definitions for each role
- [ ] Inter-agent communication tested
- [ ] Docker Compose setup
- [ ] Local development environment

### Phase 3: Workflows (Week 3)
- [ ] Feature development workflow
- [ ] Incident response workflow
- [ ] Collaborative decision engine
- [ ] Human-in-the-loop approvals
- [ ] Workflow orchestration

### Phase 4: Production Ready (Week 4)
- [ ] Kubernetes manifests
- [ ] CI/CD pipelines
- [ ] Monitoring and observability
- [ ] Documentation complete
- [ ] Published to GitHub + Docker Hub

## 9. RISK ASSESSMENT

**High Risk**
- Redis single point of failure
  → Mitigation: Redis Sentinel for HA

**Medium Risk**
- Database connection pool exhaustion
  → Mitigation: Ecto pool sizing + monitoring

**Low Risk**
- MCP protocol evolution
  → Mitigation: Version pinning + adapter pattern

## 10. SUCCESS METRICS

- [ ] All 9 agents startable via Claude Desktop
- [ ] Feature development workflow completes end-to-end
- [ ] < 100ms inter-agent message latency
- [ ] 99.9% agent uptime (via supervision)
- [ ] Zero cost for AI inference (uses Claude Desktop)

═══════════════════════════════════════════════════════════════════════
Architecture Review: APPROVED ✅
Signed: Senior Architect Agent
Next Step: Begin implementation of Phase 1
═══════════════════════════════════════════════════════════════════════
