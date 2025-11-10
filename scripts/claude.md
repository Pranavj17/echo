# scripts/

**Context:** Utility Scripts & Development Tools

This directory contains helper scripts for setup, testing, deployment, and maintenance of the ECHO system.

## Purpose

Scripts provide:
- **Setup & Installation** - Initialize system and dependencies
- **Agent Management** - Start, stop, monitor agents
- **Testing Utilities** - Test individual components
- **Database Operations** - Migrations and maintenance
- **Deployment Helpers** - Build and deploy scripts

## Directory Structure

```
scripts/
├── claude.md                  # This file
├── agents/                   # Agent-specific scripts
│   ├── test_agent_llm.sh    # Test single agent LLM
│   ├── test_all_agents_llm.sh # Test all agents LLM
│   └── [other agent scripts]
├── ollama/                   # Ollama/LLM setup scripts
│   ├── setup_models.sh      # Download all required models
│   └── verify_models.sh     # Verify models are available
├── llm/                      # LocalCode - Local LLM assistant
│   ├── localcode_session.sh  # Session management
│   ├── localcode_query.sh    # Query interface with tools
│   ├── localcode_quick.sh    # Helper functions (lc_*)
│   ├── context_builder.sh    # Tiered context injection
│   ├── query_helpers.sh      # Common query patterns
│   ├── should_query.sh       # Query decision logic
│   ├── LOCALCODE_GUIDE.md    # Complete user guide
│   ├── QUICK_START.md        # Quick start tutorial
│   └── EFFICIENCY_TEST_RESULTS.md # Performance analysis
└── [root-level utility scripts]
```

## Key Scripts

### setup.sh

**Purpose:** Complete system setup - builds all agents

**Usage:**
```bash
./setup.sh

# What it does:
# 1. Compiles shared library
# 2. Builds all 9 agent executables
# 3. Verifies compilation success
# 4. Displays build summary
```

**Requirements:**
- Elixir 1.18+ installed
- PostgreSQL running
- Redis running
- Dependencies installed (mix deps.get)

### setup_llms.sh

**Purpose:** Install Ollama and download all required AI models

**Usage:**
```bash
./setup_llms.sh

# Downloads (~48GB total):
# - qwen2.5:14b          (CEO)
# - deepseek-coder:33b   (CTO, Architect)
# - llama3.1:8b          (CHRO, PM)
# - mistral:7b           (Operations)
# - llama3.2-vision:11b  (UI/UX)
# - deepseek-coder:6.7b  (Developer)
# - codellama:13b        (Test Lead)
```

**Time:** 30-60 minutes depending on internet speed

### echo.sh

**Purpose:** System health monitoring and status

**Usage:**
```bash
./echo.sh              # Full system status
./echo.sh summary      # Brief summary
./echo.sh agents       # Agent health only
./echo.sh workflows    # Running workflows
./echo.sh messages     # Message queue status
./echo.sh decisions    # Pending decisions
```

**Sample Output:**
```
========================================
 ECHO System Status
========================================

Infrastructure:
  ✓ PostgreSQL (echo_org) - Connected
  ✓ Redis (localhost:6379) - Connected
  ✓ Ollama (localhost:11434) - 9 models loaded

Agents (9 total):
  ✓ CEO              - Running (v1.0.0)
  ✓ CTO              - Running (v1.0.0)
  ✓ CHRO             - Running (v1.0.0)
  ✓ Operations Head  - Running (v1.0.0)
  ✓ Product Manager  - Running (v1.0.0)
  ✓ Senior Architect - Running (v1.0.0)
  ✓ UI/UX Engineer   - Running (v1.0.0)
  ✓ Senior Developer - Running (v1.0.0)
  ✓ Test Lead        - Running (v1.0.0)

Activity (last 24h):
  Decisions: 42 (37 approved, 3 pending, 2 rejected)
  Messages:  187 sent, 184 read (98% read rate)
  Workflows: 5 running, 12 completed

System Health: ✓ OPERATIONAL
```

### test_agents.sh

**Purpose:** Run all agent tests

**Usage:**
```bash
./test_agents.sh

# Options:
# --agent ceo           # Test specific agent
# --verbose             # Detailed output
# --coverage            # Generate coverage report
```

### start_ceo_cto.sh / stop_ceo_cto.sh

**Purpose:** Start/stop specific agents for development

**Usage:**
```bash
# Start agents in autonomous mode
./start_ceo_cto.sh

# Stop agents
./stop_ceo_cto.sh
```

### rebuild_all.sh

**Purpose:** Clean rebuild of entire system

**Usage:**
```bash
./rebuild_all.sh

# What it does:
# 1. Cleans all build artifacts
# 2. Recompiles shared library
# 3. Rebuilds all agents
# 4. Runs tests
# 5. Verifies system health
```

### verify_all_agents.sh

**Purpose:** Comprehensive agent verification

**Usage:**
```bash
./verify_all_agents.sh

# Checks:
# - Agents compile successfully
# - Escript executables exist
# - MCP protocol compliance
# - Tool definitions valid
# - LLM models available
# - Database connectivity
# - Redis connectivity
```

### check_system_status.sh

**Purpose:** Quick system health check

**Usage:**
```bash
./check_system_status.sh

# Returns exit code:
# 0 - All systems operational
# 1 - Infrastructure issues (DB/Redis/Ollama)
# 2 - Agent issues
# 3 - Multiple issues
```

### send_message.sh

**Purpose:** Send test message between agents

**Usage:**
```bash
./send_message.sh <from_role> <to_role> <type> <subject> [content]

# Example:
./send_message.sh ceo cto request "Architecture review needed" '{"design_doc":"url"}'
```

### fix_postgres.sh

**Purpose:** Fix common PostgreSQL issues

**Usage:**
```bash
./fix_postgres.sh

# Fixes:
# - Stale connections
# - Migration conflicts
# - Permission issues
# - Database not found errors
```

### docker-setup.sh

**Purpose:** Setup Docker environment for ECHO

**Usage:**
```bash
./docker-setup.sh

# What it does:
# 1. Builds Docker images for all agents
# 2. Creates docker-compose configuration
# 3. Sets up networking
# 4. Initializes volumes
```

## Agent-Specific Scripts

### scripts/agents/test_agent_llm.sh

**Purpose:** Test LLM integration for specific agent

**Usage:**
```bash
./scripts/agents/test_agent_llm.sh ceo

# Tests:
# - Model availability
# - Connection to Ollama
# - Prompt formatting
# - Response parsing
# - Error handling
```

**Output:**
```
Testing CEO Agent LLM Integration
=================================
Model: qwen2.5:14b
Ollama Endpoint: http://localhost:11434

[1/5] Checking model availability... ✓
[2/5] Testing basic query...         ✓ (2.1s)
[3/5] Testing with context...        ✓ (3.4s)
[4/5] Testing error handling...      ✓
[5/5] Measuring response time...     ✓ (avg: 2.7s)

Result: ALL TESTS PASSED
```

### scripts/agents/test_all_agents_llm.sh

**Purpose:** Test LLM integration for all agents

**Usage:**
```bash
./scripts/agents/test_all_agents_llm.sh

# Generates report:
# - Per-agent LLM status
# - Response time comparison
# - Model availability
# - Error rates
```

## LocalCode - Local LLM Assistant

**Location:** `scripts/llm/`

LocalCode replicates Claude Code's functionality using local LLMs (deepseek-coder:6.7b). It provides project-aware AI assistance with $0 cost and 100% privacy.

### Quick Start

```bash
# Load helper functions (once per terminal session)
source ./scripts/llm/localcode_quick.sh

# Start session - auto-loads CLAUDE.md, git context, system status
lc_start

# Query local LLM
lc_query "What is ECHO?"
lc_query "How do agents communicate?"

# Interactive mode
lc_interactive

# End session (archives conversation)
lc_end
```

### Core Scripts

#### scripts/llm/localcode_session.sh

**Purpose:** Session manager - creates sessions with project context

**Usage:**
```bash
# Start new session
./scripts/llm/localcode_session.sh start [path]

# List all sessions
./scripts/llm/localcode_session.sh list

# Show session details
./scripts/llm/localcode_session.sh show <session_id>

# End session and archive
./scripts/llm/localcode_session.sh end <session_id>
```

**What it does:**
1. Creates session directory: `~/.localcode/sessions/session_ID/`
2. Loads startup context (~1,900 tokens):
   - CLAUDE.md (first 200 lines)
   - Git context (branch, commits, changed files)
   - System status (from `.claude/hooks/session-start.sh`)
   - Directory structure
3. Initializes conversation storage:
   - `session.json` - metadata
   - `startup_context.txt` - project context
   - `conversation.json` - chat history
   - `tool_results.json` - tool execution log

**Session Storage:**
```
~/.localcode/sessions/
└── session_20251111_012114_83759/
    ├── session.json           # Metadata (model, project path, turn count)
    ├── startup_context.txt    # Static project context (~1,900 tokens)
    ├── conversation.json      # Chat history (last 5 turns kept)
    └── tool_results.json      # Tool execution results (last 3 kept)
```

#### scripts/llm/localcode_query.sh

**Purpose:** Query interface with tool simulation and context management

**Usage:**
```bash
# Single query
./scripts/llm/localcode_query.sh <session_id> "your question"

# Interactive mode
./scripts/llm/localcode_query.sh <session_id> --interactive
```

**Features:**
1. **Context Assembly:**
   - Tier 1: Startup context (~1,900 tokens)
   - Tier 2: Conversation history (last 5 turns)
   - Tier 3: Tool results (last 3 executions)
   - Tier 4: Current question

2. **Context Size Warnings:**
   - >3,000 tokens: Moderate warning
   - >4,000 tokens: High warning (approaching 8K limit)
   - >6,000 tokens: Critical (blocks query)

3. **Tool Simulation:**
   - Detects `TOOL_REQUEST: function(args)` patterns
   - Executes tools automatically:
     - `read_file(path)` - Read file contents
     - `grep_code(pattern)` - Search codebase
     - `glob_files(pattern)` - Find files by pattern
     - `run_bash(command)` - Execute bash command
   - Re-queries LLM with tool results

4. **Timeout:** 180 seconds (3 minutes) for local inference

**Sample Output:**
```
═══════════════════════════════════════════════════════════
LocalCode Query (Session: session_20251111_012114_83759)
═══════════════════════════════════════════════════════════

ℹ Building query context...
ℹ Context size: 8245 bytes (~2061 tokens)
ℹ Querying deepseek-coder:6.7b (timeout: 180s)...

═══════════════════════════════════════════════════════════
Response from deepseek-coder:6.7b:
═══════════════════════════════════════════════════════════

[LLM response here]
```

#### scripts/llm/localcode_quick.sh

**Purpose:** Simplified wrapper providing helper functions

**Functions:**
- `lc_start [path]` - Start new session
- `lc_query "question"` - Query current session
- `lc_interactive` - Interactive mode
- `lc_end` - End current session
- `lc_list` - List all sessions
- `lc_show` - Show current session details

**Environment Variables:**
- `LLM_TIMEOUT=180` - Query timeout (default: 3 minutes)
- `LLM_MODEL=deepseek-coder:6.7b` - Model to use
- `LOCALCODE_SESSION` - Current session ID (auto-managed)

#### scripts/llm/context_builder.sh

**Purpose:** Tiered context injection engine for specialized queries

**Templates:**
- `code_review` - Code quality analysis
- `feature_design` - Feature planning
- `debugging` - Problem diagnosis
- `architecture` - System design
- `general` - General queries (default)

**Usage:**
```bash
./scripts/llm/context_builder.sh \
  --template code_review \
  --files "apps/ceo/lib/ceo.ex" \
  --goal "Review for security issues"
```

**Architecture:**
```
Tier 1: Static Core (~600 tokens)
  - ECHO project info
  - Tech stack (Elixir, PostgreSQL, Redis, MCP)
  - 9 agent roles
  - Critical rules

Tier 2: Dynamic Context (~1000-2000 tokens)
  - Template-specific (code files, git diff, logs, etc.)
  - Relevant documentation
  - Recent changes

Tier 3: Conversation Context (~500 tokens)
  - User goal
  - Recent decisions
  - Active workflows

Tier 4: Question (~200 tokens)
  - Specific question with instructions
  - Expected output format
```

#### scripts/llm/query_helpers.sh

**Purpose:** Helper functions for common query patterns

**Functions:**
```bash
# General query (uses context_builder.sh)
llm_query "your question"

# Code review
llm_code_review apps/ceo/lib/ceo.ex

# Feature design
llm_feature_design "Add user authentication"

# Debug help
llm_debug "Redis connection refused"

# Architecture analysis
llm_architecture

# Quick query (bypass context builder)
llm_quick "What's the current git branch?"
```

#### scripts/llm/should_query.sh

**Purpose:** Decision logic for when to query LLM vs use tools directly

**Usage:**
```bash
if ./scripts/llm/should_query.sh "$user_input"; then
  llm_query "$user_input"
else
  # Use direct tool execution
fi
```

**Query Patterns (returns 0 - should query):**
- Architecture questions
- Design decisions
- Code review requests
- Debug help
- Security analysis
- Performance optimization

**Skip Patterns (returns 1 - should skip):**
- File operations (ls, cat, head, tail)
- Git commands (status, log, diff)
- Simple searches (grep, find)
- System status checks

### Performance & Limitations

**Response Times:**
- Simple queries: 5-10 seconds
- Medium queries: 10-20 seconds
- Complex queries: 20-40 seconds
- Maximum timeout: 180 seconds (3 minutes)

**Context Capacity:**
- Startup context: ~1,900 tokens (fixed)
- Session capacity: 10-12 conversational turns
- Context growth: ~480 tokens/turn average
- Warning thresholds: 3K (moderate), 4K (high), 6K (critical)

**Limitations:**
- No streaming (waits for full response)
- Context overflow after 10-12 turns (requires session restart)
- Tool results accumulate (mitigated by keeping last 3 only)
- Local inference slower than cloud APIs

**Quality:**
- Overall grade: A- (4.25/5 stars)
- Accurate, project-aware responses
- Minor confusion on complex multi-system topics
- Excellent for quick queries and exploration

### Documentation

- **User Guide:** `scripts/llm/LOCALCODE_GUIDE.md` (406 lines)
- **Quick Start:** `scripts/llm/QUICK_START.md` (272 lines)
- **Performance:** `scripts/llm/EFFICIENCY_TEST_RESULTS.md` (326 lines)
- **Architecture:** See main `CLAUDE.md` Rule 8

### Integration with ECHO Development

**Use LocalCode for:**
1. Quick codebase exploration
2. Understanding agent implementations
3. Debugging hints (not full debugging)
4. Documentation lookup
5. Architecture clarifications

**Use Claude Code for:**
1. Complex refactoring
2. Multi-file code generation
3. Test writing and execution
4. Git operations
5. Long-running tasks

**Use Both (Dual Perspective):**
1. Code reviews (get two opinions)
2. Design decisions (compare approaches)
3. Security audits (thorough analysis)
4. Complex debugging (more insights)

### Configuration

**Environment Variables:**
```bash
# Model selection
export LLM_MODEL="deepseek-coder:6.7b"  # Default
# or
export LLM_MODEL="deepseek-coder:1.3b"  # Faster (5-10s)
export LLM_MODEL="qwen2.5:14b"          # Better quality (10-30s)

# Timeout (for slow queries)
export LLM_TIMEOUT=180   # Default: 3 minutes
export LLM_TIMEOUT=300   # 5 minutes for very complex queries

# Ollama endpoint
export OLLAMA_ENDPOINT="http://localhost:11434"
```

**Session Storage:**
```bash
# Default location
~/.localcode/sessions/

# Change with environment variable
export LOCALCODE_SESSIONS_DIR="/custom/path"
```

### Troubleshooting

**"Failed to get response from Ollama"**
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Increase timeout
export LLM_TIMEOUT=300
lc_query "your question"

# Use smaller/faster model
export LLM_MODEL="deepseek-coder:1.3b"
lc_query "your question"
```

**"Context size: 15000 bytes (~3750 tokens)" warning**
```bash
# Start fresh session
lc_end
lc_start

# Or reduce CLAUDE.md lines loaded
# Edit localcode_session.sh line ~80:
# Change: head -200 CLAUDE.md → head -100 CLAUDE.md
```

**"No active session"**
```bash
# Check current session
echo $LOCALCODE_SESSION

# Start new session
lc_start
```

### Example Workflows

**1. Learning Codebase**
```bash
lc_start
lc_interactive
> What agents exist in ECHO?
> How does the CEO agent work?
> Explain the decision-making flow
> Show me the MessageBus implementation
> exit
lc_end
```

**2. Code Review**
```bash
lc_start
lc_query "Review apps/echo_shared/lib/echo_shared/message_bus.ex for issues"
# Review local LLM perspective, then ask Claude Code same question
lc_end
```

**3. Debugging**
```bash
lc_start
lc_query "I'm getting 'connection refused' to Redis. What could be wrong?"
# Get debugging hints, then use Claude Code for implementation
lc_end
```

**4. Architecture Analysis**
```bash
lc_start
lc_query "What are the pros and cons of the dual-write pattern in MessageBus?"
# Get local LLM analysis, compare with Claude Code's perspective
lc_end
```

## Common Script Patterns

### Script Template

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined var, pipe failure

# Script metadata
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
readonly PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'  # No Color

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Description of what this script does

Options:
  -h, --help     Show this help message
  -v, --verbose  Enable verbose output

Example:
  $SCRIPT_NAME --verbose
EOF
}

# Main function
main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        usage
        exit 0
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Main script logic here
  log_info "Starting $SCRIPT_NAME..."

  # Do work

  log_info "Completed successfully"
}

# Run main function
main "$@"
```

### Error Handling Pattern

```bash
# Function with error handling
function_with_error_handling() {
  local result

  if ! result=$(risky_command 2>&1); then
    log_error "Command failed: $result"
    return 1
  fi

  echo "$result"
  return 0
}

# Cleanup on exit
cleanup() {
  log_info "Cleaning up..."
  # Cleanup logic here
}
trap cleanup EXIT
```

### Parallel Execution Pattern

```bash
# Run tasks in parallel
run_parallel() {
  local pids=()

  for task in "${TASKS[@]}"; do
    run_task "$task" &
    pids+=($!)
  done

  # Wait for all tasks
  local failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      ((failed++))
    fi
  done

  return $failed
}
```

## Environment Variables

Scripts respect these environment variables:

```bash
# Paths
export ECHO_ROOT="/path/to/echo"
export SHARED_DIR="$ECHO_ROOT/shared"
export AGENTS_DIR="$ECHO_ROOT/agents"

# Database
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="echo_org"

# Redis
export REDIS_HOST="localhost"
export REDIS_PORT="6379"

# Ollama
export OLLAMA_ENDPOINT="http://localhost:11434"

# Script behavior
export VERBOSE=false           # Enable verbose output
export DRY_RUN=false          # Show what would be done
export PARALLEL=true          # Run tasks in parallel
export LOG_LEVEL="info"       # debug|info|warn|error
```

## Creating New Scripts

### Guidelines

1. **Use the template** - Start with the script template above
2. **Add help text** - Always provide --help option
3. **Handle errors** - Use `set -euo pipefail` and trap errors
4. **Log clearly** - Use log_info, log_warn, log_error consistently
5. **Make it idempotent** - Safe to run multiple times
6. **Test thoroughly** - Test with various inputs and edge cases

### Checklist

- [ ] Shebang line: `#!/bin/bash`
- [ ] Set options: `set -euo pipefail`
- [ ] Usage function with examples
- [ ] Argument parsing
- [ ] Error handling
- [ ] Cleanup trap
- [ ] Logging
- [ ] Exit codes (0=success, non-zero=failure)
- [ ] Executable: `chmod +x script.sh`

## Debugging Scripts

### Enable Debug Mode

```bash
# Run with bash debug output
bash -x ./script.sh

# Or set in script
set -x  # Enable debug mode
```

### Check Variables

```bash
# Print all variables
set | grep ECHO_

# Verify paths
echo "Project root: $PROJECT_ROOT"
echo "Script dir: $SCRIPT_DIR"
```

### Test Without Execution

```bash
# Dry run mode
./script.sh --dry-run

# Or in script:
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Would execute: $command"
else
  $command
fi
```

## Related Documentation

- **Parent:** [../CLAUDE.md](../CLAUDE.md) - Project overview
- **Setup:** Main project setup using these scripts
- **Testing:** [../training/claude.md](../training/claude.md) - Test scripts details
- **Deployment:** [../docker/claude.md](../docker/claude.md) - Deployment scripts

---

**Remember:** Scripts should be simple, well-documented, and safe to run repeatedly. When in doubt, add a --dry-run mode.
