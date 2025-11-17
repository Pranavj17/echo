# ECHO Quick Reference Card

One-page quick reference for common ECHO tasks.

## 🚀 Essential Commands

```bash
# First Time Setup
docker-compose up -d && cd shared && mix ecto.create && mix ecto.migrate
./setup_llms.sh && ./setup.sh

# Daily Development
cd shared && mix compile && mix test
cd apps/ceo && mix compile && ./ceo --autonomous

# System Health
./echo.sh summary
docker ps | grep echo

# Monitor Dashboard
cd monitor && ./start.sh  # http://localhost:4000
```

## 🐛 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| DB connection refused | `docker-compose up -d && cd shared && mix ecto.migrate` |
| Redis failed | `docker-compose up -d && redis-cli -h 127.0.0.1 -p 6383 ping` |
| Compile errors | `cd shared && mix clean && mix compile` |
| LLM not responding | `curl http://localhost:11434/api/tags && ollama list` |
| LocalCode timeout | `export LLM_TIMEOUT=300 && lc_end && lc_start` |

## 📂 Key Files & Directories

```
/CLAUDE.md              - Start here (critical rules)
apps/                   - 9 agents + shared library + delegator
apps/echo_shared/       - Shared library (DB, Redis, MCP)
test/                   - Integration & E2E tests
scripts/llm/            - LocalCode (local AI assistant)
monitor/                - Phoenix LiveView dashboard
docs/INDEX.md           - Complete documentation index
docs/snippets/          - Reusable troubleshooting
```

## 🤖 LocalCode (Local AI Assistant)

```bash
# Setup (once per terminal)
source ./scripts/llm/localcode_quick.sh

# Use
lc_start                # Start session
lc_query "question"     # Ask question ($0 cost, 7-30s response)
lc_interactive          # Interactive mode
lc_end                  # End session

# When to use
# LocalCode: Quick questions, code exploration
# Claude Code: Complex tasks, multi-file changes
```

## 🎨 Decision Modes

| Mode | Use When | Example |
|------|----------|---------|
| **Autonomous** | Within authority | CEO approves <$1M budget |
| **Collaborative** | Team consensus | Architecture decision (CTO+Arch+Dev) |
| **Hierarchical** | Escalate up chain | Dev → Architect → CTO → CEO |
| **Human** | Critical risk | Legal, financial, strategic |

## 🔌 Key Database Tables

| Table | Purpose |
|-------|---------|
| **decisions** | Decisions with mode, status, consensus |
| **messages** | Inter-agent communications |
| **memories** | Shared organizational knowledge |
| **decision_votes** | Collaborative voting |
| **agent_status** | Health monitoring |

## 📡 Redis Channels

```
messages:ceo            # Private per-agent
messages:all            # Broadcast to all
messages:leadership     # C-suite only
decisions:new           # New decision
decisions:completed     # Decision done
agents:heartbeat        # Health checks
```

## 🧪 Testing

```bash
# Unit tests
cd apps/echo_shared && mix test
cd apps/ceo && mix test

# Integration tests
mix test test/integration/

# All tests
mix test

# With coverage
mix test --cover
```

## 🚢 Deployment

```bash
# Docker (Development)
docker-compose up -d

# Kubernetes (Production)
kubectl apply -f k8s/
kubectl get pods -n echo
```

## 📊 9 Agents & Models

| Agent | Model | Size | Purpose |
|-------|-------|------|---------|
| CEO | qwen2.5:14b | 14B | Strategic leadership |
| CTO | deepseek-coder:33b | 33B | Technology strategy |
| CHRO | llama3.1:8b | 8B | People management |
| Ops | mistral:7b | 7B | Infrastructure |
| PM | llama3.1:8b | 8B | Product strategy |
| Architect | deepseek-coder:33b | 33B | System design |
| UI/UX | llama3.2-vision:11b | 11B | Interface design |
| Dev | deepseek-coder:6.7b | 6.7B | Implementation |
| Test | codellama:13b | 13B | QA testing |

## 🔑 Critical Rules

1. **Never break tests** - `cd shared && mix test` must pass
2. **Compile shared first** - `cd shared && mix compile`
3. **Never drop DB** - Without user permission
4. **Use message bus** - All agent communication via Redis
5. **Keep it simple** - Don't overengineer

## 📞 Getting Help

| Need | See |
|------|-----|
| Architecture | `docs/architecture/ECHO_ARCHITECTURE.md` |
| Agent dev | `apps/claude.md` |
| Testing | `test/claude.md` |
| LocalCode | `scripts/claude.md` |
| Deployment | `docker/claude.md` or `k8s/claude.md` |
| Troubleshooting | `docs/snippets/` |
| Full index | `docs/INDEX.md` |

## ⚡ Performance

- **LocalCode response:** 7-30s (local LLM)
- **Agent LLM:** 3-30s depending on model size
- **Test suite:** <2min (unit + integration)
- **Full setup:** ~30-60min (includes 48GB LLM download)

---

**Quick Links:** [Full Documentation](INDEX.md) | [CLAUDE.md](../CLAUDE.md) | [README](../README.md)
