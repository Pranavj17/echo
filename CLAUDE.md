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

### Rule 8: Dual-AI Workflow (Claude Code + LocalCode)

**ECHO now has TWO AI assistant systems working together:**

#### 8.1 LocalCode - Local LLM System

**What is LocalCode?**
- Replicates Claude Code's startup flow for local LLMs (deepseek-coder:6.7b)
- $0 cost, 100% private, project-aware AI assistant
- Loads CLAUDE.md automatically, maintains conversation memory, simulates tools
- Response time: 7-30 seconds typical
- Session capacity: 10-12 conversational turns before restart needed

**Quick Commands:**
```bash
# Load helper functions (once per terminal session)
source ./scripts/llm/localcode_quick.sh

# Start session - auto-loads this CLAUDE.md, git context, system status
lc_start [path]

# Query local LLM - uses deepseek-coder:6.7b
lc_query "your question"

# Interactive mode - continuous conversation
lc_interactive

# End session - archives conversation
lc_end

# Session management
lc_list    # List active sessions
lc_show    # Show current session details
```

**Context Injection (Automatic):**
LocalCode automatically provides to deepseek-coder:6.7b:
- ✅ This CLAUDE.md file (first 200 lines) - ~1,500 tokens
- ✅ System status from `.claude/hooks/session-start.sh`
- ✅ Git context (branch, last commit, changed files)
- ✅ Directory structure (top-level)
- ✅ Conversation history (last 5 turns) - ~500-2000 tokens
- ✅ Tool execution results (last 3) - if applicable
- **Total startup context:** ~1,900 tokens
- **Warning at:** >3,000 tokens (moderate), >4,000 (high), >6,000 (blocked)

**Tool Simulation:**
Local LLM can request tools (auto-detected and executed):
```
TOOL_REQUEST: read_file(apps/ceo/lib/ceo.ex)
TOOL_REQUEST: grep_code(MessageBus.publish)
TOOL_REQUEST: glob_files(*.ex)
TOOL_REQUEST: run_bash(git log --oneline -5)
```

#### 8.2 When to Use Which AI

**Use Claude Code (Me) for:**
- ✅ Complex architectural decisions (multi-file changes)
- ✅ Long-running tasks (refactoring, test writing)
- ✅ Code generation (new features, scaffolding)
- ✅ Multi-step workflows (plan → implement → test)
- ✅ File editing and git operations
- ✅ Tasks requiring >10 steps or >30 minutes

**Use LocalCode (lc_query) for:**
- ✅ Quick questions ("How does X work?")
- ✅ Code exploration ("What's in this file?")
- ✅ Documentation lookup ("What does this function do?")
- ✅ Debugging hints ("Why might this fail?")
- ✅ Architecture clarifications ("How do agents communicate?")
- ✅ Tasks requiring <5 steps or <5 minutes

**Use BOTH (Dual Perspective) for:**
- 🤝 Code reviews (get two opinions)
- 🤝 Architectural analysis (different perspectives)
- 🤝 Design decisions (compare approaches)
- 🤝 Complex debugging (more insights)
- 🤝 Security/performance audits (thorough analysis)

#### 8.3 Dual Perspective Response Format

When appropriate, present both AI perspectives:

```
🤖 Local LLM (deepseek-coder:6.7b):
[Fast, specialized coding perspective from local model]

💭 Claude Code Analysis:
[Comprehensive analysis from frontier model]
```

**How to get dual perspective:**
```bash
# 1. Query local LLM first
lc_query "Analyze the MessageBus implementation for issues"

# 2. Then ask Claude Code the same question
# Claude will provide complementary analysis
```

#### 8.4 LocalCode Session Management Rules

**Best Practices:**
- 📏 **Context awareness** - Watch for warnings: ⚠️ "Context moderate/large"
- 🔄 **Session rotation** - Start fresh every 5-8 turns or when warned
- 💾 **Clean exits** - Always `lc_end` to archive conversation
- 🎯 **Focused queries** - Keep questions specific (reduces context growth)
- 🔧 **Tool usage** - Let LLM request tools (don't paste huge code blocks)

**Context Growth Pattern:**
```
Turn 0 (startup):  1,936 tokens
Turn 1:            2,061 tokens (+125)
Turn 3:            2,530 tokens (+469)
Turn 5:            3,376 tokens (+846) ⚠️ Moderate warning
Turn 8-10:         4,000 tokens        ⚠️ High warning
Turn 12-15:        6,000 tokens        🚨 Session restart required
```

**When to restart session:**
- ⚠️ You see "Context moderate" warning
- 🔄 Changed project branches/directories
- 🎯 Switching to different topic/task
- 💾 After 5-8 conversational turns

#### 8.5 LocalCode vs Claude Code Comparison

| Feature | LocalCode | Claude Code (Me) |
|---------|-----------|------------------|
| **Cost** | $0 (local) | $0.015/query (API) |
| **Privacy** | 100% local | Cloud-based |
| **Speed** | 7-30s | 2-5s |
| **Context** | 8K window (~6K safe) | 200K window |
| **Memory** | Session-based | Native |
| **Tools** | Simulated | Native |
| **Quality** | Good (6.7B) | Excellent (Sonnet 4.5) |
| **Project Aware** | ✅ Yes | ✅ Yes |
| **Best For** | Quick queries | Complex tasks |

#### 8.6 Integration with ECHO Agents

**Future enhancement:** ECHO agents can use LocalCode internally:
```elixir
# Instead of:
DecisionHelper.consult(:ceo, question, context)

# Could use:
LocalCode.query(session_id, question, context)
# Returns: Project-aware, conversational AI response
```

**Benefits for agents:**
- Each agent gets project-aware reasoning
- $0 cost per consultation
- 100% private (no external API calls)
- Conversation memory across agent interactions

#### 8.7 Configuration & Environment

**Environment variables:**
```bash
export LLM_MODEL="deepseek-coder:6.7b"  # Model to use
export LLM_TIMEOUT=180                  # Query timeout (3 minutes)
export OLLAMA_ENDPOINT="http://localhost:11434"
```

**Alternative models:**
```bash
export LLM_MODEL="llama3.1:8b"          # Faster, general purpose
export LLM_MODEL="deepseek-coder:33b"   # Slower, more powerful
export LLM_MODEL="qwen2.5:14b"          # Best reasoning
export LLM_MODEL="codellama:13b"        # Code-focused
```

#### 8.8 Documentation & Help

**Full documentation:**
- `scripts/llm/QUICK_START.md` - Simple tutorial
- `scripts/llm/LOCALCODE_GUIDE.md` - Complete reference
- `scripts/llm/README.md` - Context injection architecture
- `scripts/llm/EFFICIENCY_TEST_RESULTS.md` - Performance analysis

**Quick help:**
```bash
source ./scripts/llm/localcode_quick.sh
# Displays available commands automatically
```

#### 8.9 Common Pitfalls & Solutions

**Issue:** "Failed to get response from Ollama"
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Check model exists
ollama list | grep deepseek-coder

# Pull model if missing
ollama pull deepseek-coder:6.7b
```

**Issue:** "Context too large" warning
```bash
# Solution 1: End and restart session
lc_end && lc_start

# Solution 2: Use shorter questions
# Instead of: "Explain everything about X, Y, Z..."
# Do: "What is X?" then "How does Y work?" then "Explain Z"

# Solution 3: Clear tool results (if many tools used)
# Restart session to clear accumulated tool outputs
```

**Issue:** Slow responses (>60 seconds)
```bash
# Solution 1: Increase timeout
export LLM_TIMEOUT=300  # 5 minutes

# Solution 2: Use smaller/faster model
export LLM_MODEL="deepseek-coder:1.3b"

# Solution 3: Reduce context
# Keep questions shorter, restart session more frequently
```

**Issue:** Inaccurate responses
```bash
# LocalCode is good but not perfect. For critical tasks:
# 1. Use dual perspective (check with Claude Code)
# 2. Verify answers against code/docs
# 3. Use larger model (deepseek-coder:33b or qwen2.5:14b)
```

#### 8.10 Workflow Integration Examples

**Example 1: Code Review Workflow**
```bash
# 1. Start session
lc_start

# 2. Quick understanding
lc_query "What does apps/ceo/lib/ceo.ex do?"

# 3. Detailed review
lc_query "Review the approve_strategic_initiative function for bugs"

# 4. Get second opinion from Claude Code
# Ask me: "Review approve_strategic_initiative in apps/ceo/lib/ceo.ex"

# 5. Compare insights
# Local LLM: Fast, code-focused feedback
# Claude Code: Deeper architectural concerns
```

**Example 2: Debugging Workflow**
```bash
lc_start

# Quick diagnosis
lc_query "I'm getting 'connection refused' to Redis. What could cause this?"

# If tool request appears
# LocalCode auto-executes: run_bash(docker ps | grep redis)

# Get detailed fix
lc_query "How do I fix Redis connection in ECHO?"

# For implementation, switch to Claude Code
# I'll help write the actual fix with proper error handling
```

**Example 3: Learning Workflow**
```bash
lc_interactive

> What are the 9 agents in ECHO?
[Gets overview]

> How does the CEO agent make decisions?
[Learns about DecisionEngine]

> Show me an example of autonomous vs collaborative mode
[Gets code examples]

> What happens if CEO budget limit is exceeded?
[Understands escalation flow]

> exit

# Now have full context, ready to implement features
```

**Example 4: Architecture Exploration**
```bash
lc_start

# High-level
lc_query "Explain ECHO's message bus architecture"

# Dive deeper
lc_query "What's the dual-write pattern in MessageBus?"

# Potential issues
lc_query "What race conditions exist in the message bus?"

# Get comprehensive analysis from Claude Code
# Ask me: "Do deep architectural review of MessageBus with race condition analysis"
# I'll provide extensive analysis + code fixes
```

#### 8.11 Testing & Validation

**Verified performance (see EFFICIENCY_TEST_RESULTS.md):**
- ✅ Response times: 7-30 seconds (acceptable)
- ✅ Context capacity: 10-12 conversational turns
- ✅ Quality: Accurate, project-aware responses (4/5 stars)
- ✅ Warning system: Triggers correctly at >3K tokens
- ✅ Overall grade: A- (4.25/5 stars)

**Tested scenarios:**
1. Simple queries (1 sentence) - 7s response, excellent quality
2. Medium queries (architecture) - 10-15s, good quality
3. Complex queries (multi-part) - 20-30s, good quality
4. Context warnings - Correctly triggered at 3,376 tokens

#### 8.12 Summary: Dual-AI Development Workflow

**The Power of Two AI Systems:**

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  Quick Question? → lc_query "..."              │
│  Complex Task?   → Ask Claude Code             │
│  Need Both?      → Dual Perspective Review     │
│                                                 │
│  Result: Faster development, better quality    │
│          $0 cost for quick queries             │
│          100% private for sensitive code       │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Golden Rule:**
Start with LocalCode for exploration → Switch to Claude Code for implementation → Use both for validation

**This is a force multiplier for ECHO development!** 🚀

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
