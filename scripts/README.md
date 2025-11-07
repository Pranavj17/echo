# ECHO Scripts

Utility scripts for managing, testing, and operating the ECHO multi-agent system.

## Directory Structure

```
scripts/
├── README.md              # This file
├── setup/                 # Initial setup and installation
├── agents/                # Agent management scripts
├── testing/               # Testing and verification
└── utils/                 # General utilities
```

## Quick Reference

### First Time Setup
```bash
./scripts/setup/setup.sh              # Complete setup
./scripts/setup/setup_llms.sh         # Install Ollama models
./scripts/setup/docker-setup.sh       # Setup Docker infrastructure
```

### Agent Management
```bash
./scripts/agents/start_ceo_cto.sh     # Start CEO and CTO agents
./scripts/agents/stop_ceo_cto.sh      # Stop CEO and CTO agents
./scripts/agents/rebuild_all.sh       # Rebuild all agents
```

### Testing
```bash
./scripts/testing/test_agents.sh      # Test all agents
./scripts/testing/verify_all_agents.sh # Verify agent builds
```

### Utilities
```bash
./scripts/utils/echo.sh summary       # System status summary
./scripts/utils/check_system_status.sh # Health check
```

## Script Categories

### `/setup/` - Installation & Setup

**setup.sh**
- Complete ECHO installation
- Compiles shared library
- Builds all 9 agents
- Runs initial verification

**setup_llms.sh**
- Installs Ollama (if not present)
- Downloads all 9 LLM models
- Verifies model installation
- ~48GB download

**docker-setup.sh**
- Starts PostgreSQL and Redis containers
- Creates database and runs migrations
- Verifies container health

### `/agents/` - Agent Management

**start_ceo_cto.sh**
- Starts CEO and CTO agents for testing
- Useful for development workflows
- Runs in autonomous mode

**stop_ceo_cto.sh**
- Stops CEO and CTO agents gracefully
- Cleanup of background processes

**rebuild_all.sh**
- Recompiles shared library
- Rebuilds all 9 agent escripts
- Quick iteration during development

### `/testing/` - Testing & Verification

**test_agents.sh**
- Runs unit tests for all agents
- Tests MCP tool implementations
- Validates agent configurations

**verify_all_agents.sh**
- Verifies all agents compile
- Checks MCP server functionality
- Validates database connectivity

### `/utils/` - General Utilities

**echo.sh**
- Swiss army knife for ECHO management
- Commands: summary, status, agents, decisions, messages
- Primary development tool

**check_system_status.sh**
- System health check
- PostgreSQL, Redis, Ollama status
- Quick diagnostic tool

## Script Conventions

### Error Handling
All scripts use:
```bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

### Project Root
Scripts reliably find project root:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

### Output Format
- ✅ Success messages in green
- ❌ Error messages in red
- ℹ️ Info messages in blue
- ⚠️ Warnings in yellow

### Logging
Scripts log to:
- `logs/scripts/` - Script execution logs
- `logs/agents/` - Agent-specific logs
- stderr - Errors and warnings

## Creating New Scripts

### Template

```bash
#!/usr/bin/env bash
# Description: Brief description of what this script does

set -euo pipefail

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Change to project root
cd "$PROJECT_ROOT" || {
  echo "Error: Failed to change to project directory" >&2
  exit 1
}

# Main logic
main() {
  echo "Doing something..."
}

# Run main
main "$@"
```

### Best Practices
1. **Add description** - First comment should explain purpose
2. **Use `set -euo pipefail`** - Fail fast on errors
3. **Find project root** - Don't assume working directory
4. **Validate inputs** - Check arguments before use
5. **Provide usage** - Show help with `--help` flag
6. **Log important actions** - Especially destructive operations
7. **Make executable** - `chmod +x script.sh`

## Common Patterns

### Wait for Service
```bash
wait_for_postgres() {
  for i in {1..30}; do
    if psql -U postgres -h localhost -p 5433 -c "SELECT 1" &>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}
```

### Cleanup on Exit
```bash
cleanup() {
  echo "Cleaning up..."
  # Cleanup logic
}
trap cleanup EXIT
```

### Progress Indication
```bash
step() {
  echo "▶ $1..."
}

step "Compiling shared library"
cd shared && mix compile

step "Building agents"
./scripts/agents/rebuild_all.sh
```

## Troubleshooting

### Script Fails with "Permission Denied"
```bash
chmod +x scripts/path/to/script.sh
```

### Can't Find Project Root
Ensure script uses the standard pattern:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

### PostgreSQL Connection Errors
```bash
# Check PostgreSQL is running
./scripts/utils/check_system_status.sh

# Or start Docker
./scripts/setup/docker-setup.sh
```

## Related Documentation

- **Development:** [../CLAUDE.md](../CLAUDE.md)
- **Testing:** [../test/README.md](../test/README.md)
- **Agents:** [../agents/claude.md](../agents/claude.md)

---

**Last Updated:** 2025-11-06
**Script Count:** 48 scripts (organized into 4 categories)
**Conventions:** Bash best practices, error handling, logging
