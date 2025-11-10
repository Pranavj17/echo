# LocalCode - Claude Code Flow for Local LLM

**Status:** ✅ WORKING - Successfully tested with deepseek-coder:6.7b

## What is LocalCode?

LocalCode replicates Claude Code's startup flow for local LLMs (deepseek-coder:6.7b, llama, etc.). It provides:

1. **Session Management** - Maintains conversation state across queries
2. **Context Injection** - Automatically loads project context from CLAUDE.md
3. **Tool Simulation** - Read files, search code, run bash commands
4. **Memory** - Remembers conversation history (stateless LLM → stateful assistant)

## Quick Start

### 1. Start a Session

```bash
# Start session in current directory
./scripts/llm/localcode_session.sh start

# Or specify project path
./scripts/llm/localcode_session.sh start /path/to/project

# Returns: session_20251111_005410_55928
```

**What happens:**
- Loads CLAUDE.md (project rules, architecture)
- Runs `.claude/hooks/session-start.sh` (system status)
- Captures git context (branch, commits)
- Lists directory structure
- Creates session folder in `~/.localcode/sessions/`

### 2. Query the LLM

```bash
# Single query
./scripts/llm/localcode_query.sh session_ID "What is the ECHO architecture?"

# Interactive mode
./scripts/llm/localcode_query.sh session_ID --interactive
```

**Example output:**
```
═══════════════════════════════════════════
LocalCode Query (Session: session_...)
═══════════════════════════════════════════

ℹ Building query context...
ℹ Querying deepseek-coder:6.7b...

═══════════════════════════════════════════
Response from deepseek-coder:6.7b:
═══════════════════════════════════════════

The ECHO project is an AI-powered organizational model where
autonomous role-based agents communicate via the Model Context
Protocol (MCP). The architecture consists of 9 independent agent
MCP servers, each with specialized LLMs via Ollama...

[Full detailed response about agents, infrastructure, decision modes]
```

### 3. Interactive Mode

```bash
./scripts/llm/localcode_query.sh session_ID --interactive

localcode> What agents exist in ECHO?
[LLM responds with list of 9 agents]

localcode> How do they communicate?
[LLM explains Redis pub/sub + PostgreSQL]

localcode> exit
```

### 4. Manage Sessions

```bash
# List all sessions
./scripts/llm/localcode_session.sh list

# Show session details
./scripts/llm/localcode_session.sh show session_ID

# End session (archives to ~/.localcode/sessions/archive/)
./scripts/llm/localcode_session.sh end session_ID
```

## How It Works

### Architecture

```
┌─────────────────────────────────────────────────┐
│ Session: session_20251111_005410_55928         │
│ Location: ~/.localcode/sessions/session_ID/    │
│                                                  │
│ Files:                                           │
│ ├─ session.json         # Metadata              │
│ ├─ startup_context.txt  # Project context       │
│ ├─ conversation.json    # Chat history          │
│ └─ tool_results.json    # Tool execution log    │
└─────────────────────────────────────────────────┘
                      │
                      ▼
         ┌─────────────────────────┐
         │ Context Builder          │
         │ (Tiered Injection)       │
         │                          │
         │ 1. Startup Context       │
         │ 2. Conversation History  │
         │ 3. Tool Results          │
         │ 4. Current Question      │
         └────────────┬─────────────┘
                      │
                      ▼
            ┌───────────────────┐
            │ Ollama API        │
            │ deepseek-coder    │
            └─────────┬─────────┘
                      │
                      ▼
               ┌────────────┐
               │ Response   │
               └────────────┘
```

### Context Injection

Every query receives:

```
## PROJECT OVERVIEW
[From CLAUDE.md - 200 lines of project rules, architecture]

### System Status
{
  "infrastructure": {
    "postgres": "✅ Connected",
    "redis": "✅ Connected",
    "ollama": "✅ 7 models"
  },
  "agents": "9 running"
}

### Git Context
Branch: feature/flow-dsl-event-driven
Last Commit: feat: Implement event-driven Flow DSL

### Directory Structure
[Top-level files and folders]

## CONVERSATION HISTORY (Last 5 turns)
[USER] What is ECHO?
[ASSISTANT] ECHO is a multi-agent AI organizational model...

[USER] How do agents communicate?
[ASSISTANT] Via Redis pub/sub channels + PostgreSQL...

## RECENT TOOL EXECUTIONS
[TOOL: read_file(apps/ceo/lib/ceo.ex)]
defmodule Ceo do...

## CURRENT QUESTION
What are the key security considerations for the message bus?

Provide a clear, technical answer. If you need files, say:
TOOL_REQUEST: read_file(path) or grep_code(pattern) or run_bash(command)
```

### Tool Simulation

The LLM can request tools:

```
LLM: To answer this, I need to see the MessageBus code.
TOOL_REQUEST: read_file(apps/echo_shared/lib/echo_shared/message_bus.ex)
```

LocalCode detects this, executes:
```bash
head -100 /path/to/file
```

Then re-queries with results:
```
## TOOL RESULTS
[TOOL RESULT: read_file(...)]
defmodule EchoShared.MessageBus do
  def publish_message(from, to, type, subject, content) do
    # Dual-write pattern
    case store_message_in_db(...) do
      {:ok, db_message} ->
        Redix.command(:redix, ["PUBLISH", channel, ...])
    end
  end
end

Now answer the original question with this code.
```

### Supported Tools

```bash
# File reading
TOOL_REQUEST: read_file(apps/ceo/lib/ceo.ex)

# Code search
TOOL_REQUEST: grep_code(MessageBus.publish)

# Find files
TOOL_REQUEST: glob_files(*.ex)

# Run commands
TOOL_REQUEST: run_bash(git log --oneline -5)
```

## Comparison: Claude Code vs LocalCode

| Feature | Claude Code | LocalCode |
|---------|-------------|-----------|
| **Conversation Memory** | ✅ Native (200K tokens) | ✅ Simulated (JSON file) |
| **File Reading** | ✅ Read tool | ✅ Tool simulation |
| **Code Search** | ✅ Grep/Glob tools | ✅ Tool simulation |
| **Bash Execution** | ✅ Bash tool | ✅ Tool simulation |
| **Project Context** | ✅ Auto-loads CLAUDE.md | ✅ Auto-loads CLAUDE.md |
| **Session Hooks** | ✅ session-start.sh | ✅ session-start.sh |
| **Context Window** | 200K tokens | 8K tokens (configurable) |
| **Cost** | API pricing | $0 (local) |
| **Speed** | ~2-5 seconds | ~2-5 seconds |
| **Model** | Claude Sonnet 4.5 | deepseek-coder:6.7b |

## Configuration

Edit `~/.localcode/config` (optional):

```bash
# Model selection
export LLM_MODEL="deepseek-coder:6.7b"
# Or: llama3.1:8b, codellama:13b, qwen2.5:14b

# Ollama endpoint
export OLLAMA_ENDPOINT="http://localhost:11434"

# Context window size
export OLLAMA_CONTEXT_SIZE=8192

# Temperature
export OLLAMA_TEMPERATURE=0.7
```

## Use Cases

### 1. Project Exploration

```bash
./scripts/llm/localcode_session.sh start /path/to/new/project
session_ID=$(cat /tmp/last_session)

./scripts/llm/localcode_query.sh $session_ID \
  "What is this project? Explain the architecture."

# LLM reads CLAUDE.md, analyzes structure, explains
```

### 2. Code Review

```bash
./scripts/llm/localcode_query.sh $session_ID \
  "Review the MessageBus implementation for security issues."

# LLM may request: TOOL_REQUEST: read_file(apps/echo_shared/lib/echo_shared/message_bus.ex)
# Then provides detailed analysis
```

### 3. Debugging

```bash
./scripts/llm/localcode_query.sh $session_ID \
  "I'm getting 'connection refused' errors. Debug this."

# LLM may request:
# TOOL_REQUEST: run_bash(docker ps | grep redis)
# TOOL_REQUEST: grep_code(Redix.start_link)
# Then diagnoses issue
```

### 4. Architecture Questions

```bash
./scripts/llm/localcode_query.sh $session_ID --interactive

localcode> How do agents make autonomous decisions?
[Detailed explanation of DecisionEngine, authority limits, confidence thresholds]

localcode> What's the message flow from CEO to CTO?
[Traces through MessageBus.publish → Redis → MessageHandler]

localcode> exit
```

## Advanced Features

### Custom Context per Query

You can inject additional context:

```bash
# Read file first
CODE=$(cat apps/ceo/lib/ceo.ex)

# Query with extra context
./scripts/llm/localcode_query.sh $session_ID \
  "Review this code: $CODE. Look for race conditions."
```

### Multi-Session Comparison

```bash
# Session A: main branch
session_a=$(./scripts/llm/localcode_session.sh start .)

# Checkout feature branch
git checkout feature/new-stuff

# Session B: feature branch
session_b=$(./scripts/llm/localcode_session.sh start .)

# Compare
./scripts/llm/localcode_query.sh $session_a "Summarize the architecture"
./scripts/llm/localcode_query.sh $session_b "Summarize the architecture"
# Diff the responses
```

### Session Replay

```bash
# Show conversation
./scripts/llm/localcode_session.sh show $session_ID

# Replay specific turn
jq '.[] | select(.role == "assistant") | .content' \
  ~/.localcode/sessions/$session_ID/conversation.json
```

## Troubleshooting

### "Failed to get response from Ollama"

```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Check model exists
ollama list | grep deepseek-coder

# Pull model if missing
ollama pull deepseek-coder:6.7b
```

### "Session not found"

```bash
# List active sessions
./scripts/llm/localcode_session.sh list

# Session may be archived
ls ~/.localcode/sessions/archive/
```

### Slow Responses

```bash
# Use smaller model
export LLM_MODEL="deepseek-coder:1.3b"

# Or reduce context
# (Edit startup_context.txt to be shorter)
```

### Context Too Large

```bash
# Reduce CLAUDE.md injection
# Edit localcode_session.sh line:
head -100 CLAUDE.md  # Change to head -50
```

## Future Enhancements

- [ ] Streaming responses (real-time output)
- [ ] Multi-agent chat (multiple LLMs in one session)
- [ ] Context caching (faster queries)
- [ ] Web UI (browser-based interface)
- [ ] Plugin system (custom tools)
- [ ] Cloud sync (share sessions across machines)

## Credits

Built for ECHO project as part of dual-AI system (Claude + Local LLM).

Inspired by Claude Code's excellent developer experience.
