# CLAUDE.md

This file provides guidance to Claude Code when working with the ECHO repository.

## 🎯 Project Overview

**ECHO (Executive Coordination & Hierarchical Organization)** is an AI-powered organizational model where autonomous role-based agents communicate via the Model Context Protocol (MCP). Each agent is an independent MCP server that can connect to Claude Desktop or other MCP clients.

**Vision:** Enable AI agents to operate as autonomous workers that make decisions, collaborate, escalate appropriately, and require human approval for critical actions.

## 🏗️ Architecture

```
Claude Desktop / MCP Client
    ├──> 9 Independent Agent MCP Servers (CEO, CTO, CHRO, Ops, PM, Architect, UI/UX, Dev, Test)
    │    └──> Each has specialized LLM via Ollama
    └──> Shared Infrastructure
         ├── PostgreSQL (decisions, messages, memories, votes, agent status)
         └── Redis (message bus, pub/sub, real-time coordination)
```

**Tech Stack:** Elixir 1.18, PostgreSQL 16, Redis 7, MCP 2024-11-05, Ollama (9 specialized local models), Phoenix LiveView

## 📂 Repository Structure

Each major directory has its own `claude.md` with focused context:
- `/CLAUDE.md` - This file (project overview & critical rules)
- `apps/claude.md` - Agent development patterns
- `apps/echo_shared/claude.md` - Shared library API
- `test/claude.md` - Integration & E2E testing
- `scripts/claude.md` - Utility scripts & LocalCode
- `workflows/claude.md` - Multi-agent workflows
- `monitor/claude.md` - Phoenix LiveView dashboard
- `docker/claude.md` - Deployment & containerization

**When working in a specific directory, reference its `claude.md` for focused context.**

## 🚨 Critical Rules - READ FIRST

### Rule 1: Never Break Existing Tests
- **ALWAYS run tests** before committing changes
- All tests must pass: `cd shared && mix test`
- If tests fail, fix the code, don't modify tests to pass

### Rule 2: Respect the Autonomous Flag
- Agents run as MCP servers by default (stdio mode)
- Use `--autonomous` flag for standalone mode: `./ceo --autonomous`
- MCP servers exit when stdin closes - this is expected behavior

### Rule 3: Compile Shared Library First
- The `shared/` library is a dependency for all agents
- Always compile shared before agents: `cd shared && mix compile`

### Rule 4: Database Safety
- **NEVER run** `mix ecto.drop` or `mix ecto.reset` without explicit user permission
- Use migrations for schema changes: `mix ecto.migrate`

### Rule 5: Don't Overengineer
- Start with the simplest solution
- Consult the user before adding complexity
- Follow existing patterns before inventing new ones

### Rule 6: MCP Protocol Compliance
- Use `EchoShared.MCP.Server` behavior - don't roll your own
- JSON-RPC 2.0 over stdio is the transport layer

### Rule 7: Message Bus Discipline
- All inter-agent communication via Redis pub/sub
- Use `EchoShared.MessageBus` functions
- Never bypass the message bus for direct communication

### Rule 8: Dual-AI Workflow (Claude Code + LocalCode)

**ECHO has TWO AI assistant systems:**

**LocalCode** - Local LLM assistant (deepseek-coder:6.7b)
- $0 cost, 100% private, project-aware
- Response time: 7-30 seconds
- Session capacity: 10-12 conversational turns

**Quick Commands:**
```bash
source ./scripts/llm/localcode_quick.sh  # Load once per terminal
lc_start        # Start session with auto-context
lc_query "..."  # Query local LLM
lc_interactive  # Interactive mode
lc_end          # End and archive session
```

**When to Use:**
- **Claude Code (me):** Complex tasks, multi-file changes, refactoring, git operations
- **LocalCode:** Quick questions, code exploration, documentation lookup, debugging hints
- **Both:** Code reviews, architectural decisions, dual perspectives

**Context Awareness:**
- Startup: ~1,900 tokens (CLAUDE.md first 200 lines + git + system status)
- Warning at: >3,000 tokens (moderate), >4,000 (high), >6,000 (restart required)
- Restart session every 5-8 turns to avoid context overflow

**Full LocalCode documentation:** See `scripts/claude.md` (Rule 8 complete guide, 400+ lines) or `scripts/llm/QUICK_START.md`

### Rule 9: Documentation Organization

**All documentation organized in `docs/` folders:**
- `docs/architecture/` - System architecture documents
- `docs/guides/` - User guides and tutorials
- `docs/completed/` - Completed implementation reports
- `docs/troubleshooting/` - Troubleshooting guides
- `apps/{app}/docs/` - App-specific documentation

**Rules:**
- ✅ **DO** create `docs/` folders when adding documentation
- ✅ **DO** keep only `CLAUDE.md` and `README.md` at project root
- ❌ **DON'T** leave loose `.md` files at project root

## 🚀 Quick Start Commands

### First Time Setup
```bash
docker-compose up -d                    # Start PostgreSQL + Redis
cd shared && mix ecto.create && mix ecto.migrate
./setup_llms.sh                         # Install Ollama models (~48GB)
./setup.sh                              # Build all agents
```

### Daily Development
```bash
cd shared && mix compile && mix test    # Compile shared library
cd agents/ceo && mix deps.get && mix compile && mix test
./ceo                                   # Run as MCP server
./ceo --autonomous                      # Run in standalone mode
```

### Testing & Monitoring
```bash
./echo.sh summary                       # System health check
./scripts/agents/test_agent_llm.sh ceo  # Test LLM integration
cd monitor && ./start.sh                # Start dashboard (http://localhost:4000)
```

## 🐛 Troubleshooting Quick Reference

**Database connection refused:**
```bash
docker-compose up -d && cd shared && mix ecto.migrate
```

**Redis connection failed:**
```bash
docker-compose up -d && redis-cli -h 127.0.0.1 -p 6383 ping
```

**Agent compile errors:**
```bash
cd shared && mix clean && mix compile
cd agents/ceo && rm -rf _build deps && mix deps.get && mix compile
```

**LLM not responding:**
```bash
curl http://localhost:11434/api/tags && ollama list
```

**LocalCode issues:**
```bash
# Check Ollama
curl http://localhost:11434/api/tags

# Restart session if context warning
lc_end && lc_start

# Increase timeout for slow queries
export LLM_TIMEOUT=300
```

## 🎨 Decision Modes

ECHO agents use 4 decision-making patterns:

1. **Autonomous** - Agent decides within authority limits
2. **Collaborative** - Multiple agents vote for consensus
3. **Hierarchical** - Escalates up the reporting chain
4. **Human-in-the-Loop** - Critical decisions need human approval

See `apps/echo_shared/claude.md` for detailed decision engine documentation.

## 📊 Key Database Tables

- **decisions** - Organizational decisions with mode, status, consensus
- **messages** - Inter-agent communications with threading
- **memories** - Shared organizational knowledge (key-value + tags)
- **decision_votes** - Collaborative voting records
- **agent_status** - Health monitoring and heartbeats

## 🔌 Redis Channels

```
messages:{role}        # Private per-agent (e.g., messages:ceo)
messages:all           # Broadcast to all agents
messages:leadership    # C-suite only
decisions:new          # New decision initiated
decisions:vote_required # Vote needed
decisions:completed    # Decision finalized
agents:heartbeat       # Agent health checks
```

## ⚠️ Common Pitfalls

1. **Forgetting to compile shared library first** - Always `cd shared && mix compile`
2. **Running agents without --autonomous for testing** - Use `--autonomous` for standalone mode
3. **Modifying database without migrations** - Use `mix ecto.gen.migration`
4. **Bypassing message bus** - All communication must go through Redis + PostgreSQL
5. **Not checking if PostgreSQL/Redis are running** - `docker ps | grep echo`

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

## 🤝 Contributing Guidelines

1. **Read the focused context** - Check the `claude.md` in the directory you're working in
2. **Follow existing patterns** - Look at similar code before implementing
3. **Run tests** - Always ensure tests pass
4. **Keep it simple** - Don't overengineer solutions
5. **Ask before major changes** - Consult user for architectural decisions

## 📞 Getting Help

- **Architecture:** `docs/architecture/ECHO_ARCHITECTURE.md`
- **Agent development:** `apps/claude.md`
- **Shared library:** `apps/echo_shared/claude.md`
- **Testing:** `test/claude.md`
- **LocalCode:** `scripts/claude.md` (Rule 8 complete guide)
- **Workflows:** `workflows/claude.md`
- **Deployment:** `docker/claude.md`

---

**Remember:** This is a complex multi-agent system. Simplicity in implementation is key to maintainability.

---

# Detailed Documentation (Below First 200 Lines)

The sections below provide comprehensive details not included in the first 200 lines for token optimization.

## 🔍 9 Agent Roles (Detailed)

| Agent | Model | Size | Purpose |
|-------|-------|------|---------|
| **CEO** | qwen2.5:14b | 14B | Strategic leadership and budget decisions |
| **CTO** | deepseek-coder:33b | 33B | Technology strategy and architecture review |
| **CHRO** | llama3.1:8b | 8B | People management and communication |
| **Operations Head** | mistral:7b | 7B | Infrastructure optimization |
| **Product Manager** | llama3.1:8b | 8B | Product strategy and prioritization |
| **Senior Architect** | deepseek-coder:33b | 33B | System design and technical specifications |
| **UI/UX Engineer** | llama3.2-vision:11b | 11B | Design evaluation and visual understanding |
| **Senior Developer** | deepseek-coder:6.7b | 6.7B | Fast code generation and implementation |
| **Test Lead** | codellama:13b | 13B | Test generation and quality assurance |

## 🔧 Environment Variables (Detailed)

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

# LocalCode (see scripts/claude.md for details)
LLM_MODEL=deepseek-coder:6.7b   # Model to use
LLM_TIMEOUT=180                  # Query timeout (3 minutes)
LOCALCODE_SESSIONS_DIR=~/.localcode/sessions/
```

## 📚 Documentation Map (Complete)

### Project Documentation (`./docs/`)

| Document | Location | Purpose |
|----------|----------|---------|
| **Architecture** | | |
| `ECHO_ARCHITECTURE.md` | `docs/architecture/` | Complete system architecture and design decisions |
| `DELEGATOR_ARCHITECTURE.md` | `docs/architecture/` | Delegator agent resource optimization |
| `FLOW_DSL_IMPLEMENTATION.md` | `docs/architecture/` | Event-driven Flow DSL implementation details |
| `TOKEN_OPTIMIZATION_ANALYSIS.md` | `docs/architecture/` | Token optimization strategies and analysis |
| **Guides** | | |
| `README.md` | `./ (root)` | User-facing getting started guide |
| `GETTING_STARTED.md` | `docs/guides/` | Step-by-step setup instructions |
| `DEMO_GUIDE.md` | `docs/guides/` | 10 demo scenarios with examples |
| `claude-desktop-setup.md` | `docs/guides/` | Connect agents to Claude Desktop |
| `DELEGATOR_QUICK_START.md` | `docs/guides/` | Delegator agent quick start |
| **Completed** | | |
| `DAY2_TRAINING_COMPLETE.md` | `docs/completed/` | Day 2 training completion report |
| `DAY3_TRAINING_COMPLETE.md` | `docs/completed/` | Day 3 training completion report |
| `SECURITY_FIXES.md` | `docs/completed/` | Security hardening implementation |
| `SCRIPT_CLEANUP_SUMMARY.md` | `docs/completed/` | Script cleanup and umbrella migration |

### App-Specific Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| `apps/claude.md` | `apps/` | Agent development patterns |
| `apps/echo_shared/claude.md` | `apps/echo_shared/` | Shared library API reference |
| `apps/delegator/claude.md` | `apps/delegator/` | Delegator agent (resource optimization) |
| **Session Consult** | | |
| `SESSION_CONSULT_INTEGRATION_FINAL_REPORT.md` | `apps/echo_shared/docs/` | Complete integration report |
| `LLM_SESSION_INTEGRATION_SUMMARY.md` | `apps/echo_shared/docs/` | Integration summary |

## 🧪 Testing Philosophy (Detailed)

- **Unit Tests:** Test individual components in isolation
  - Location: `apps/*/test/`
  - Run: `cd apps/ceo && mix test`
- **Integration Tests:** Test multi-agent workflows end-to-end
  - Location: `test/integration/`
  - See `test/claude.md` for patterns
- **System Tests:** Load testing, failover scenarios, audit trails
  - Location: `test/e2e/`
  - Tagged with `@moduletag :e2e`
- **All tests must pass before committing**

## 🚀 Complete Deployment Guide

See `docker/claude.md` for:
- Docker Compose setup
- Kubernetes manifests
- Production deployment
- Scaling strategies
- Monitoring and logging

## 📈 Performance & Monitoring

### Monitor Dashboard
```bash
cd monitor && ./start.sh
# Open http://localhost:4000
```

**Features:**
- Real-time agent activity
- Decision flow tracking
- Performance metrics
- Activity timeline

See `monitor/claude.md` for dashboard development.

## 🔐 Security Best Practices

1. **Never commit secrets** - Use environment variables
2. **Validate all MCP tool inputs** - Prevent injection attacks
3. **Respect agent authority limits** - Check before executing
4. **Audit trail** - All decisions and messages persisted
5. **Database transactions** - Use Ecto transactions for consistency

See `docs/completed/SECURITY_FIXES.md` for security hardening details.

## 🎯 Advanced Topics

### LocalCode - Complete Guide

See `scripts/claude.md` for comprehensive LocalCode documentation including:
- Context injection architecture (tiered system)
- Tool simulation (auto-detection and execution)
- Session management (lifecycle, context growth)
- Dual perspective workflows (LocalCode + Claude Code)
- Configuration and environment variables
- Performance metrics and optimization
- Troubleshooting guide
- 10+ workflow integration examples

**Key features:**
- $0 cost per query (local inference)
- 100% private (no external API calls)
- Project-aware (auto-loads CLAUDE.md, git context, system status)
- Tool simulation (read_file, grep_code, glob_files, run_bash)
- Conversation memory (last 5 turns)
- Context warnings (prevents overflow)

**When to use LocalCode:**
- Quick questions: "How does X work?"
- Code exploration: "What's in this file?"
- Documentation lookup: "What does this function do?"
- Debugging hints: "Why might this fail?"
- Architecture clarifications: "How do agents communicate?"

**When to use Claude Code:**
- Complex architectural decisions
- Multi-file refactoring
- Code generation (new features)
- Test writing and execution
- Git operations (commits, PRs)
- Tasks requiring >10 steps or >30 minutes

**Dual perspective approach:**
1. Query LocalCode for fast, code-focused perspective
2. Query Claude Code for comprehensive analysis
3. Compare insights for best outcome

### Delegator Agent

See `apps/delegator/claude.md` for complete delegator documentation.

**Purpose:** Intelligent agent coordinator that spawns only required agents per session.

**Benefits:**
- ⚡ 50-85% reduction in CPU/memory usage
- 🚀 Faster startup (load only necessary LLMs)
- 🎯 Better UX (relevant agents for task)
- 💰 Resource efficiency (scale based on needs)

**Example:**
```
Task: "Fix typo in README"
Before: 9 agents loaded (~48GB)
After: 1 agent loaded (Developer, ~7GB)
Savings: 85% memory reduction
```

### Workflows

See `workflows/claude.md` for multi-agent workflow patterns and orchestration.

## 🛠️ Advanced Troubleshooting

### Debug Mode
```bash
# Enable debug logging for agent
export AGENT_LOG_LEVEL=debug
./ceo --autonomous

# Enable debug logging for shared library
export ECHO_SHARED_LOG_LEVEL=debug
```

### Database Issues
```bash
# Stale connections
cd shared && MIX_ENV=test mix ecto.reset

# Migration conflicts
cd shared && mix ecto.rollback && mix ecto.migrate

# Permission issues
GRANT ALL PRIVILEGES ON DATABASE echo_org TO echo_org;
```

### Redis Issues
```bash
# Clear all keys (WARNING: destructive)
redis-cli -h 127.0.0.1 -p 6383 FLUSHALL

# Monitor messages in real-time
redis-cli -h 127.0.0.1 -p 6383
> SUBSCRIBE messages:all

# Check memory usage
redis-cli -h 127.0.0.1 -p 6383 INFO memory
```

### Ollama / LLM Issues
```bash
# Check Ollama status
curl http://localhost:11434/api/tags

# List installed models
ollama list

# Pull missing model
ollama pull deepseek-coder:6.7b

# Test model inference
curl http://localhost:11434/api/generate -d '{
  "model": "deepseek-coder:6.7b",
  "prompt": "def hello():",
  "stream": false
}'

# Monitor Ollama logs
docker logs -f ollama  # If running in Docker
```

### LocalCode Troubleshooting

See `scripts/claude.md` (Section 8.9) for complete LocalCode troubleshooting guide.

**Common issues:**
- "Failed to get response from Ollama" → Check Ollama running, increase timeout
- "Context too large" warning → Restart session (`lc_end && lc_start`)
- Slow responses (>60s) → Use smaller model or increase timeout
- Inaccurate responses → Use dual perspective (check with Claude Code)

## 🎓 Learning Resources

### For New Contributors

1. Start with `README.md` - High-level overview
2. Read `CLAUDE.md` (this file) - Development guidelines
3. Explore `docs/guides/GETTING_STARTED.md` - Step-by-step setup
4. Study `apps/claude.md` - Agent development patterns
5. Review `apps/ceo/` - Reference implementation
6. Experiment with `scripts/llm/` - Try LocalCode assistant

### For Advanced Development

1. `docs/architecture/ECHO_ARCHITECTURE.md` - Deep dive into system design
2. `apps/echo_shared/claude.md` - Shared library internals
3. `workflows/claude.md` - Multi-agent orchestration
4. `test/claude.md` - Integration testing patterns
5. `docker/claude.md` - Production deployment

## 📊 Project Statistics

- **Total Lines of Code:** ~15,000+ (Elixir)
- **Number of Agents:** 9 independent MCP servers
- **LLM Models:** 9 specialized models (~48GB total)
- **Database Tables:** 6 core tables (decisions, messages, memories, etc.)
- **Redis Channels:** 10+ pub/sub channels
- **Claude.md Files:** 12 files (127KB total documentation)
- **Test Coverage:** >80% (unit + integration tests)

## 🌟 Future Roadmap

**Phase 5: Production Readiness**
- Kubernetes deployment automation
- Horizontal scaling for agents
- Load balancing and failover
- Advanced monitoring and alerting

**Phase 6: Advanced Features**
- Inter-organization communication
- External API integrations
- Machine learning for decision optimization
- Natural language workflow definitions

---

**End of CLAUDE.md** - For detailed context on specific areas, see the focused `claude.md` files in each directory.
