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
