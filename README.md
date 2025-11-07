# ECHO - Executive Coordination & Hierarchical Organization

**An AI-powered organizational model with autonomous role-based agents communicating via MCP protocol**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Elixir](https://img.shields.io/badge/Elixir-1.18-purple.svg)](https://elixir-lang.org/)
[![MCP Protocol](https://img.shields.io/badge/MCP-2024--11--05-blue.svg)](https://modelcontextprotocol.io/)

## 🎯 Vision

ECHO enables future tech companies to operate with AI workers that:
- **Make autonomous decisions** within their authority
- **Collaborate through consensus** when needed
- **Escalate to appropriate authority** levels
- **Require human approval** for critical decisions
- **Communicate naturally** across organizational hierarchies

## 🏗️ Architecture

Each organizational role runs as an **independent MCP server** that Claude Desktop (or any MCP client) can connect to:

```
Claude Desktop / MCP Client
         ├──> mcp-server-ceo
         ├──> mcp-server-cto
         ├──> mcp-server-chro
         ├──> mcp-server-operations
         ├──> mcp-server-product-manager
         ├──> mcp-server-architect
         ├──> mcp-server-uiux
         ├──> mcp-server-developer
         └──> mcp-server-test-lead

All agents share:
├── PostgreSQL (organizational memory)
└── Redis (message bus)
```

## 📊 Monitoring Dashboard

**NEW**: Real-time Phoenix LiveView dashboard for monitoring agent activities!

```bash
cd monitor
./start.sh
# Open http://localhost:4000
```

Features:
- 📈 **Overview**: Daily agent activity summary
- 🔗 **Power Delegation**: Decision flow tracking
- 📊 **Performance**: Agent metrics and efficiency
- ⏱️ **Timeline**: Real-time activity feed

See [MONITORING_DASHBOARD_GUIDE.md](MONITORING_DASHBOARD_GUIDE.md) for details.

## 🚀 Quick Start

### Prerequisites

- Elixir 1.18+ with Erlang/OTP 27
- PostgreSQL 16+
- Redis 7+
- Ollama (for local AI models)
- Claude Desktop (for MCP client)

### Setup in 3 Steps

**1. Start infrastructure:**
```bash
# macOS with Homebrew
brew services start postgresql
brew services start redis

# Or use Nix shell (includes all dependencies)
nix-shell
```

**2. Setup database, LLMs, and agents:**
```bash
# Create database and run migrations
cd shared
mix ecto.create
mix ecto.migrate
cd ..

# Install Ollama and download AI models (~48GB)
./setup_llms.sh

# Build all agents
./setup.sh
```

**3. Configure Claude Desktop:**

The setup script automatically creates the configuration. Just restart Claude Desktop!

**Manual configuration:** See `CLAUDE_DESKTOP_SETUP.md`

### Verify Installation

```bash
# Check system health
./echo.sh summary

# Expected output:
# ● System Status: OPERATIONAL
# Infrastructure: ✓ PostgreSQL, ✓ Redis
# Agents: ✓ 3 / 9 agents healthy

# Test LLM integration for specific agent
./scripts/agents/test_agent_llm.sh ceo

# Test all agents' LLM integration
./scripts/agents/test_all_agents_llm.sh
```

### First Demo

Open Claude Desktop and try:

```
Use the CEO agent to approve a strategic initiative:
- Name: "AI Research Lab"
- Budget: $750,000
- Expected outcome: "Advanced AI capabilities"
```

See `DEMO_GUIDE.md` for 10 comprehensive demo scenarios.

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [CLAUDE_DESKTOP_SETUP.md](./CLAUDE_DESKTOP_SETUP.md) | Connect agents to Claude Desktop |
| [DEMO_GUIDE.md](./DEMO_GUIDE.md) | 10 demo scenarios with examples |
| [ECHO_ARCHITECTURE.md](./ECHO_ARCHITECTURE.md) | Complete system architecture |
| [AGENT_INTEGRATION_GUIDE.md](./AGENT_INTEGRATION_GUIDE.md) | Agent implementation details |
| [LLM_TESTING_SUCCESS.md](./LLM_TESTING_SUCCESS.md) | LLM integration testing guide |
| [OLLAMA_SETUP_COMPLETE.md](./OLLAMA_SETUP_COMPLETE.md) | Ollama and model setup |
| [DISTRIBUTED_SYSTEMS_IMPROVEMENTS.md](./DISTRIBUTED_SYSTEMS_IMPROVEMENTS.md) | Reliability & observability |
| [ECHO_SH_README.md](./ECHO_SH_README.md) | Monitoring script documentation |

## 🤖 Available Agents

Each agent has AI assistance via specialized local LLM models:

| Agent | Role | AI Model | Status |
|-------|------|----------|--------|
| CEO | Strategic leadership, budget allocation | qwen2.5:14b | ✅ Built + AI |
| CTO | Technology strategy, architecture | deepseek-coder:33b | ✅ Built + AI |
| CHRO | Human resources, talent management | llama3.1:8b | ✅ Built + AI |
| Operations Head | Infrastructure and operations | mistral:7b | ✅ Built + AI |
| Product Manager | Product strategy, prioritization | llama3.1:8b | ✅ Built + AI |
| Senior Architect | System design, technical specs | deepseek-coder:33b | ✅ Built + AI |
| UI/UX Engineer | Interface design, user experience | llama3.2-vision:11b | ✅ Built + AI |
| Senior Developer | Feature implementation, coding | deepseek-coder:6.7b | ✅ Built + AI |
| Test Lead | Quality assurance, testing | codellama:13b | ✅ Built + AI |

All agents use **local AI models via Ollama** - zero API costs, complete privacy, works offline.

## 🎯 Key Features

### AI-Powered Decision Making

Every agent has an `ai_consult` tool for AI-assisted analysis:

```elixir
# CEO consulting AI for strategic decision
ai_consult(
  query_type: "decision_analysis",
  question: "Should we expand to European market?",
  context: %{
    options: ["Immediate expansion", "Pilot program", "Defer"],
    budget: "$5M",
    timeline: "12 months"
  }
)
```

**Benefits:**
- 🔒 **Private** - All AI runs locally, no cloud APIs
- 💰 **Free** - Zero API costs after setup
- 🎯 **Specialized** - Each role has domain-specific model
- ⚡ **Fast** - Low latency for real-time decisions
- 🌐 **Offline** - Works without internet

### Decision Modes

**Autonomous** - Agent makes decision within authority:
```elixir
# CEO can approve budgets under $1M autonomously
approve_budget(amount: 750_000)  # ✅ Autonomous
approve_budget(amount: 5_000_000) # ⬆️ Escalates to human
```

**Collaborative** - Multiple agents vote/consensus:
```elixir
# CTO proposes architecture, team votes
propose_architecture(design: "Microservices")
# → Senior Architect, Operations, Product Manager vote
```

**Hierarchical** - Escalates up reporting chain:
```elixir
# Developer uncertain → Architect → CTO → CEO
escalate_technical_decision(issue: "Database choice")
```

**Human-in-the-Loop** - Critical decisions require human:
```elixir
# Legal, financial, or strategic risks
escalate_to_human(reason: "Regulatory compliance")
```

### Inter-Agent Communication

Agents communicate via Redis pub/sub + PostgreSQL persistence:

```elixir
# Product Manager → CTO
publish_message(
  from: :product_manager,
  to: :cto,
  type: :request,
  subject: "Technical feasibility review"
)
```

### Workflow Engine

Define multi-agent workflows:

```elixir
workflow "Feature Development" do
  step :product_manager, "define_requirements"
  step :senior_architect, "design_system"
  step :cto, "approve_architecture"

  parallel do
    step :senior_developer, "implement_backend"
    step :ui_ux_engineer, "design_ui"
  end

  step :test_lead, "create_test_plan"
  step :ceo, "approve_budget"
end
```

### Health Monitoring

Real-time system observability:

```bash
./echo.sh           # Full system status
./echo.sh agents    # Agent health with heartbeats
./echo.sh workflows # Running workflows
./echo.sh messages  # Message queue status
./echo.sh decisions # Pending decisions
```

## 🚧 Development Status

**Current Phase:** Phase 4 - Workflows & Integration

**Completed:**
- ✅ Phase 1: Foundation (shared library, MCP protocol, database schemas)
- ✅ Phase 2: CEO agent (reference implementation)
- ✅ Phase 3: All 9 agents implemented
- ✅ Phase 4.1: Distributed systems improvements (reliability, observability)

**In Progress:**
- 🔄 Workflow engine testing
- 🔄 Integration with external systems
- 🔄 Production deployment guides

See [ECHO_ARCHITECTURE.md](./ECHO_ARCHITECTURE.md) for complete architecture design.

## 📄 License

MIT License

---

**ECHO** - Building the future of AI-powered organizations, one agent at a time. 🚀
