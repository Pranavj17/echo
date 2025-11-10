# Local LLM Context Builder

Optimized context injection system for querying local Ollama models with maximum accuracy.

## Architecture

**Problem:** Local LLM (6.7B params) vs Claude (frontier model) has context gap:
- Claude: 200K tokens, full conversation history, dynamic tool access
- Local LLM: Single prompt, no memory, limited context

**Solution:** "Context Compiler" - Distill 30K context → 2.5K optimal signal

## Tiered Context Injection

```
┌─────────────────────────────────────────┐
│ TIER 1: Static Core (~500 tokens)      │
│  ├─ Project identity                   │
│  ├─ Current branch/phase               │
│  ├─ Critical rules (top 5)             │
│  └─ Tech stack summary                 │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ TIER 2: Dynamic Task (~1500 tokens)    │
│  ├─ Relevant code snippets             │
│  ├─ File structure (focused)           │
│  ├─ Schema/API relevant to task        │
│  └─ Error messages (if debugging)      │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ TIER 3: Conversation (~300 tokens)     │
│  ├─ User's current goal                │
│  ├─ Last 2-3 exchanges summary         │
│  └─ Decisions made so far              │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ TIER 4: Specific Question (~200 tokens)│
│  └─ Precise question to answer         │
└─────────────────────────────────────────┘
```

**Total:** ~2500 tokens (optimal for local LLM inference)

## Usage

### Option 1: Helper Functions (Recommended)

```bash
# Source the helpers
source scripts/llm/query_helpers.sh

# Simple query
llm_query "What's the best way to implement X?"

# Code review
llm_code_review "shared/lib/message_bus.ex" \
    "Review for security issues" \
    "$(cat shared/lib/message_bus.ex | head -50)"

# Feature design
llm_feature_design "Event-driven workflow" \
    "How should I architect this?" \
    "EchoShared.WorkflowEngine, EchoShared.MessageBus"

# Debugging
llm_debug "Connection refused to Redis" \
    "What could cause this?" \
    "$(cat error.log)"

# Architecture
llm_architecture "Agent communication" \
    "Should we use GenServer or Agent?" \
    "Need concurrent access to shared state"

# Quick query (no context)
llm_quick "What is Elixir?"
```

### Option 2: Direct Script Usage

```bash
# General query
./scripts/llm/context_builder.sh general \
    --question "How should I implement feature X?" \
    --goal "Add workflow orchestration"

# Code review
./scripts/llm/context_builder.sh code_review \
    --question "Review this for security issues" \
    "shared/lib/message_bus.ex" "1-50" "$(cat file.ex)"

# Feature design
./scripts/llm/context_builder.sh feature_design \
    --question "Best architecture for X?" \
    "Feature X" "Module1, Module2"

# Debugging
./scripts/llm/context_builder.sh debugging \
    --question "Why is this failing?" \
    "Error message" "Stack trace" "Recent changes"

# Architecture
./scripts/llm/context_builder.sh architecture \
    --question "Design question?" \
    "Component name" "Additional context"
```

## Templates

### 1. Code Review Template
- **Use when:** Reviewing code for bugs, performance, security, style
- **Context includes:** File path, code snippet, related modules, schema
- **Example:** "Review this GenServer for race conditions"

### 2. Feature Design Template
- **Use when:** Designing new features or components
- **Context includes:** Feature name, related modules, architecture patterns
- **Example:** "How to implement collaborative decision voting?"

### 3. Debugging Template
- **Use when:** Fixing errors, understanding failures
- **Context includes:** Error message, stack trace, recent changes
- **Example:** "Why is the database connection failing?"

### 4. Architecture Template
- **Use when:** High-level design questions
- **Context includes:** Component, existing patterns, constraints
- **Example:** "Should we use pub/sub or direct messaging?"

### 5. General Template
- **Use when:** Broad questions without specific context type
- **Context includes:** Minimal project overview
- **Example:** "What's the best way to handle retries?"

## Query Decision Logic

### ✅ QUERY the LLM when:
- Code architecture decisions
- Debugging complex issues
- Design pattern suggestions
- Security/performance analysis
- Comparing implementation approaches
- "What could go wrong?" scenarios
- Reviewing complex code

### ❌ SKIP the LLM when:
- File/directory listing (use `ls`, `Glob`)
- Reading file contents (use `Read`)
- Running commands (use `Bash`)
- Simple factual recalls
- Obvious next steps
- Git operations

## Configuration

Environment variables:
```bash
export OLLAMA_ENDPOINT="http://localhost:11434"  # Ollama API endpoint
export LLM_MODEL="deepseek-coder:6.7b"          # Default model
export LLM_TIMEOUT="30000"                       # Query timeout (ms)
export PROJECT_ROOT="/path/to/echo"              # Auto-detected
```

## Examples

### Example 1: Review Flow DSL Code

```bash
source scripts/llm/query_helpers.sh

# Get LLM perspective on Flow DSL implementation
CODE=$(cat workflows/flow_dsl.ex)
llm_code_review "workflows/flow_dsl.ex" \
    "Review this Flow DSL implementation. Check for: 1) Security issues 2) Performance concerns 3) Elixir best practices" \
    "$CODE"
```

### Example 2: Debug Agent Communication

```bash
# Agent not receiving messages
llm_debug "Agent not receiving messages from Redis" \
    "Debug why CEO agent subscription isn't working. Check: 1) Redis connection 2) Channel naming 3) Subscription logic" \
    "Error: No messages received after 30s"
```

### Example 3: Design New Feature

```bash
# Design collaborative voting system
llm_feature_design "Multi-agent voting for decisions" \
    "Design a voting system where multiple agents can vote on decisions. Consider: 1) Vote weight by role 2) Tie-breaking 3) Timeout handling 4) Persistence" \
    "EchoShared.Decisions, EchoShared.MessageBus"
```

### Example 4: Architecture Question

```bash
# State management approach
llm_architecture "Agent state management" \
    "Should agents use GenServer, Agent, or ETS for state? Need: 1) Concurrent access 2) Crash recovery 3) Audit trail" \
    "Each agent needs to maintain connection state, pending decisions, and conversation history"
```

## Testing

Test the system works:

```bash
# Quick test
source scripts/llm/query_helpers.sh
llm_quick "What is Elixir in one sentence?"

# Full context test
llm_query "What are the key components of ECHO?" \
    "Focus on MCP protocol and agent communication"
```

## Performance

- **Local inference:** ~2-5 seconds for 6.7B model
- **No API costs:** Runs locally via Ollama
- **Privacy:** No data leaves machine
- **Accuracy:** With proper context, matches frontier model quality

## Integration with Claude Code

Claude Code uses this system via:
1. **Rule 8** in `CLAUDE.md` - Always query local LLM first
2. **Dual perspective responses:**
   ```
   🤖 Local LLM (deepseek-coder:6.7b):
   [LLM response via context builder]

   💭 My Analysis:
   [Claude's perspective]
   ```

## Future Enhancements

- [ ] Add token counting for context optimization
- [ ] Cache static core context for faster queries
- [ ] Support streaming responses for long answers
- [ ] Add conversation memory persistence
- [ ] Template customization per ECHO agent role
- [ ] Metrics collection (query time, token usage)

## Troubleshooting

**"Failed to get response from Ollama"**
```bash
curl http://localhost:11434/api/tags  # Check Ollama running
ollama list | grep deepseek          # Verify model installed
```

**"Context builder not found"**
```bash
chmod +x scripts/llm/context_builder.sh
chmod +x scripts/llm/query_helpers.sh
```

**Slow responses**
```bash
export LLM_TIMEOUT="60000"  # Increase timeout
export LLM_MODEL="deepseek-coder:1.3b"  # Use smaller model
```

## Credits

Built for ECHO project as part of dual-perspective AI system.
