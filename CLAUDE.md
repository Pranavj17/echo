# CLAUDE.md

This file provides guidance to Claude Code when working with the ECHO repository.

## 🎯 Project Overview

**ECHO (Executive Coordination & Hierarchical Organization)** is an AI-powered organizational model where autonomous role-based agents communicate via the Model Context Protocol (MCP). Each agent is an independent MCP server that can connect to Claude Desktop or other MCP clients.

**Vision:** Enable AI agents to operate as autonomous workers that make decisions, collaborate, escalate appropriately, and require human approval for critical actions.

## 🏗️ Architecture at a Glance

```
Claude Desktop / MCP Client
    ├──> 9 Independent Agent MCP Servers (CEO, CTO, CHRO, Ops, PM, Architect, UI/UX, Dev, Test)
    │    └──> Each has specialized LLM via Ollama
    │
    └──> Shared Infrastructure
         ├── PostgreSQL (decisions, messages, memories, votes, agent status)
         └── Redis (message bus, pub/sub, real-time coordination)
```

**9 Agent Roles:**
- **CEO** - Strategic leadership (qwen2.5:14b)
- **CTO** - Technology strategy (deepseek-coder:33b)
- **CHRO** - HR management (llama3.1:8b)
- **Operations Head** - Infrastructure (mistral:7b)
- **Product Manager** - Product strategy (llama3.1:8b)
- **Senior Architect** - System design (deepseek-coder:33b)
- **UI/UX Engineer** - Interface design (llama3.2-vision:11b)
- **Senior Developer** - Implementation (deepseek-coder:6.7b)
- **Test Lead** - QA testing (codellama:13b)

## 📂 Repository Structure & Context Files

Each major directory has its own `claude.md` with focused context:

```
echo/
├── CLAUDE.md                    # This file - project overview & critical rules
├── agents/claude.md             # Agent development patterns
├── shared/claude.md             # Shared library usage guide
├── monitor/claude.md            # Phoenix LiveView dashboard
├── workflows/claude.md          # Multi-agent workflow patterns
├── training/claude.md           # Training scripts & testing
├── scripts/claude.md            # Utility scripts
└── docker/claude.md             # Deployment & containerization
```

**When working in a specific directory, reference its `claude.md` for focused context.**

## 🚨 Critical Rules - READ FIRST

### Rule 1: Never Break Existing Tests
- **ALWAYS run tests** before committing changes
- All tests must pass: `cd shared && mix test`
- Agents must compile: `cd agents/{role} && mix compile`
- If tests fail, fix the code, don't modify tests to pass

### Rule 2: Respect the Autonomous Flag
- Agents run as MCP servers by default (stdio mode)
- Use `--autonomous` flag for standalone mode: `./ceo --autonomous`
- MCP servers exit when stdin closes - this is expected behavior
- Don't try to "fix" this - it's by design

### Rule 3: Compile Shared Library First
- The `shared/` library is a dependency for all agents
- Always compile shared before agents:
  ```bash
  cd shared && mix compile
  cd agents/ceo && mix deps.get && mix compile
  ```
- Agents won't compile if shared library has errors

### Rule 4: Database Safety
- **NEVER run** `mix ecto.drop` or `mix ecto.reset` without explicit user permission
- Database contains organizational memory across all agents
- Use migrations for schema changes: `mix ecto.migrate`
- Test migrations with rollback: `mix ecto.rollback`

### Rule 5: Don't Overengineer
- Start with the simplest solution
- Consult the user before adding complexity
- ECHO already has complex architecture - keep implementations simple
- Follow existing patterns before inventing new ones

### Rule 6: MCP Protocol Compliance
- Agents must implement MCP 2024-11-05 specification
- Use `EchoShared.MCP.Server` behavior - don't roll your own
- JSON-RPC 2.0 over stdio is the transport layer
- Standard methods: `initialize`, `tools/list`, `tools/call`

### Rule 7: Message Bus Discipline
- All inter-agent communication via Redis pub/sub
- Use `EchoShared.MessageBus` functions
- Messages must also persist to PostgreSQL
- Never bypass the message bus for direct communication

### Rule 8: Local LLM Integration (Dual Perspective Workflow)
- **ALWAYS** query local Ollama LLM (deepseek-coder:6.7b) before responding to user requests
- Present both perspectives separately in this format:
  ```
  🤖 Local LLM (deepseek-coder:6.7b):
  [LLM's response]

  💭 My Analysis:
  [Claude's response]
  ```
- Query endpoint: `http://localhost:11434/api/generate`
- Send context including:
  - User's question/task
  - Relevant code snippets
  - ECHO project context
  - Current understanding
- Use `"stream": false` for synchronous responses
- Timeout: 30 seconds for LLM queries
- This provides dual AI perspectives: local specialized coding model + Claude's analysis

## 🚀 Quick Start Commands

### First Time Setup
```bash
# Start infrastructure (PostgreSQL + Redis via Docker)
docker-compose up -d

# Verify containers are running
docker ps | grep echo

# Setup database and install LLMs (~48GB)
cd shared && mix ecto.create && mix ecto.migrate
./setup_llms.sh

# Build all agents
./setup.sh
```

### Daily Development
```bash
# Compile shared library
cd shared && mix compile && mix test

# Work on specific agent
cd agents/ceo
mix deps.get
mix compile
mix escript.build
mix test

# Run agent as MCP server
./ceo  # Stdio mode for Claude Desktop

# Run agent in autonomous mode
./ceo --autonomous  # Standalone mode for testing
```

### Testing & Verification
```bash
# Check system health
./echo.sh summary

# Test LLM integration
./scripts/agents/test_agent_llm.sh ceo

# Run all agent tests
./test_agents.sh

# Monitor dashboard
cd monitor && ./start.sh
# Open http://localhost:4000
```

## 🔑 Key Technologies

- **Language:** Elixir 1.18 / Erlang/OTP 27
- **Database:** PostgreSQL 16 (ACID transactions, audit trail)
- **Message Bus:** Redis 7 (pub/sub, real-time events)
- **Protocol:** MCP 2024-11-05 (JSON-RPC 2.0 over stdio)
- **AI Models:** Ollama (9 specialized local models)
- **Dashboard:** Phoenix LiveView (real-time monitoring)

## 🎨 Decision Modes

ECHO agents use 4 decision-making patterns:

1. **Autonomous** - Agent decides within authority limits
   ```elixir
   %{mode: :autonomous, initiator_role: :ceo}
   # CEO can approve budgets up to $1M without escalation
   ```

2. **Collaborative** - Multiple agents vote for consensus
   ```elixir
   %{mode: :collaborative, participants: [:ceo, :cto, :product_manager]}
   # Architecture decisions require team consensus
   ```

3. **Hierarchical** - Escalates up the reporting chain
   ```elixir
   %{mode: :hierarchical, escalate_to: :ceo}
   # Developer → Architect → CTO → CEO
   ```

4. **Human-in-the-Loop** - Critical decisions need human approval
   ```elixir
   %{mode: :human, reason: "Legal compliance", urgency: :high}
   # Regulatory, financial, or strategic risks
   ```

## 📊 Database Schema Overview

**decisions** - Organizational decisions with mode, status, consensus
**messages** - Inter-agent communications with threading
**memories** - Shared organizational knowledge (key-value + tags)
**decision_votes** - Collaborative voting records
**agent_status** - Health monitoring and heartbeats

See `shared/claude.md` for detailed schema documentation.

## 🔌 Redis Channels

```
messages:{role}        # Private per-agent (e.g., messages:ceo)
messages:all           # Broadcast to all agents
messages:leadership    # C-suite only (CEO, CTO, CHRO, Ops)
decisions:new          # New decision initiated
decisions:vote_required # Vote needed from participant
decisions:completed    # Decision finalized
decisions:escalated    # Escalated to higher authority
agents:heartbeat       # Agent health checks
```

## 🧪 Testing Philosophy

- **Unit Tests:** Test individual components in isolation
- **Integration Tests:** Test multi-agent workflows end-to-end
- **System Tests:** Load testing, failover scenarios, audit trails
- **All tests must pass before committing**

Location: `shared/test/`, `agents/*/test/`, `test/integration/`

## 📚 Documentation Map

| Document | Purpose |
|----------|---------|
| `ECHO_ARCHITECTURE.md` | Complete system architecture and design decisions |
| `README.md` | User-facing getting started guide |
| `GETTING_STARTED.md` | Step-by-step setup instructions |
| `DEMO_GUIDE.md` | 10 demo scenarios with examples |
| `CLAUDE_DESKTOP_SETUP.md` | Connect agents to Claude Desktop |
| `PHASE_4_ARCHITECTURE.md` | Current phase implementation details |
| `agents/claude.md` | Agent development patterns |
| `shared/claude.md` | Shared library API reference |

## 🔧 Environment Variables

```bash
# Database (Docker on port 5433)
DB_HOST=localhost
DB_USER=echo_org
DB_PASSWORD=postgres
DB_PORT=5433
DB_NAME=echo_org

# Redis (Docker on port 6383)
REDIS_HOST=localhost
REDIS_PORT=6383

# Ollama
OLLAMA_ENDPOINT=http://localhost:11434

# Agent-specific
AUTONOMOUS_BUDGET_LIMIT=1000000  # CEO authority limit
CEO_MODEL=qwen2.5:14b           # Override default model
CEO_LLM_ENABLED=true            # Enable/disable LLM
```

## ⚠️ Common Pitfalls

1. **Forgetting to compile shared library first**
   - Always `cd shared && mix compile` before working on agents

2. **Running agents without --autonomous flag for testing**
   - MCP servers exit when stdin closes (expected)
   - Use `--autonomous` for standalone testing

3. **Modifying database without migrations**
   - Create migration: `cd shared && mix ecto.gen.migration name`
   - Never edit database directly

4. **Bypassing message bus**
   - All communication must go through Redis + PostgreSQL
   - Don't create direct agent-to-agent channels

5. **Not checking if PostgreSQL/Redis are running**
   ```bash
   docker ps | grep echo            # Check Docker containers
   PGPASSWORD=postgres psql -h 127.0.0.1 -p 5433 -U echo_org -d echo_org -c "SELECT 1"
   redis-cli -h 127.0.0.1 -p 6383 ping
   ```

## 🐛 Troubleshooting

**"Database connection refused"**
```bash
docker-compose up -d              # Start containers
docker ps | grep echo_postgres    # Verify running
cd shared && mix ecto.migrate
```

**"Redis connection failed"**
```bash
docker-compose up -d              # Start containers
docker ps | grep echo_redis       # Verify running
redis-cli -h 127.0.0.1 -p 6383 ping  # Should return PONG
```

**"Agent not receiving messages"**
```bash
redis-cli
> SUBSCRIBE messages:ceo  # Test subscription
```

**"Compile errors in agent"**
```bash
cd shared && mix clean && mix compile
cd agents/ceo && rm -rf _build deps && mix deps.get && mix compile
```

**"LLM not responding"**
```bash
curl http://localhost:11434/api/tags  # Check Ollama is running
ollama list                           # List installed models
```

## 📖 Current Phase

**Phase 4: Workflows & Integration** (In Progress)

**Completed:**
- ✅ Phase 1: Foundation (shared library, MCP protocol, database schemas)
- ✅ Phase 2: CEO agent (reference implementation)
- ✅ Phase 3: All 9 agents with LLM integration

**In Progress:**
- 🔄 Workflow engine testing
- 🔄 Multi-agent workflow examples
- 🔄 Integration test suite

**Roadmap:**
- Production deployment guides
- Kubernetes manifests
- Advanced workflow patterns

## 🤝 Contributing Guidelines

1. **Read the focused context** - Check the `claude.md` in the directory you're working in
2. **Follow existing patterns** - Look at similar code before implementing
3. **Run tests** - Always ensure tests pass
4. **Keep it simple** - Don't overengineer solutions
5. **Ask before major changes** - Consult user for architectural decisions

## 📞 Getting Help

- **Architecture questions:** See `ECHO_ARCHITECTURE.md`
- **Agent development:** See `agents/claude.md`
- **Shared library:** See `shared/claude.md`
- **Workflows:** See `workflows/claude.md`
- **Deployment:** See `docker/claude.md`

---

**Remember:** This is a complex multi-agent system. Simplicity in implementation is key to maintainability.
