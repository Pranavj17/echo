# ECHO Test Suite

Comprehensive testing infrastructure for the ECHO multi-agent system.

## Directory Structure

```
test/
├── README.md              # This file
├── integration/           # Multi-component integration tests
├── e2e/                   # End-to-end workflow tests
└── fixtures/              # Test data and fixtures
```

## Test Categories

### Integration Tests (`integration/`)
Tests that verify multiple components working together:

- **Database + Redis** - Message persistence and pub/sub
- **Agent Communication** - Message bus between agents
- **Decision Workflows** - Collaborative decision-making
- **LLM Integration** - Ollama API calls and responses

**Examples:**
- `test_agent_messaging_test.exs` - Agent-to-agent communication
- `test_decision_workflow_test.exs` - Multi-agent decisions
- `test_redis_pubsub_test.exs` - Redis pub/sub reliability

### End-to-End Tests (`e2e/`)
Complete workflow tests simulating real-world scenarios:

- **Feature Development** - PM → Architect → Dev → Test → CEO
- **Hiring Workflow** - CHRO → CEO collaborative decisions
- **Incident Response** - Multi-agent coordination

**Examples:**
- `test_feature_development_workflow.sh` - Full feature workflow
- `test_hiring_workflow.sh` - Complete hiring process
- `test_autonomous_mode.sh` - Agents running standalone

### Fixtures (`fixtures/`)
Reusable test data for consistent testing:

- `sample_decisions.json` - Decision test data
- `sample_messages.json` - Message test data
- `sample_agents.json` - Agent configuration data
- `sample_workflows.json` - Workflow definitions

## Running Tests

### All Tests
```bash
cd /Users/pranav/Documents/echo
./scripts/testing/test_all.sh
```

### Integration Tests Only
```bash
cd shared
mix test test/integration/
```

### E2E Tests Only
```bash
cd test/e2e
./test_feature_development_workflow.sh
```

### Specific Test File
```bash
cd shared
mix test test/integration/agent_messaging_test.exs
```

## Writing Tests

### Integration Test Template

```elixir
defmodule Echo.Integration.YourTest do
  use ExUnit.Case, async: false  # Database access = no async

  alias EchoShared.MessageBus
  alias EchoShared.Schemas.Message
  alias EchoShared.Repo

  setup do
    # Clean database before each test
    Repo.delete_all(Message)
    :ok
  end

  describe "your feature" do
    test "does what you expect" do
      # Arrange

      # Act

      # Assert
      assert true
    end
  end
end
```

### E2E Test Template

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== E2E Test: Your Workflow ==="

# Setup
cd "$(dirname "$0")/../.."
source scripts/utils/test_helpers.sh

# Test steps
step "Start agents" start_test_agents
step "Send message" send_test_message
step "Verify outcome" verify_test_result

# Cleanup
cleanup_test_agents

echo "✅ Test passed!"
```

## Test Helpers

### `scripts/utils/test_helpers.sh`
Common test utilities:

```bash
# Start agents in background
start_test_agents() { ... }

# Stop test agents
cleanup_test_agents() { ... }

# Send test message
send_test_message() { ... }

# Wait for condition
wait_for() { ... }

# Assert equality
assert_equal() { ... }
```

## CI/CD Integration

### GitHub Actions Workflow

```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: echo_org_test
          POSTGRES_PASSWORD: postgres

      redis:
        image: redis:7-alpine

    steps:
      - uses: actions/checkout@v3
      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18'
          otp-version: '27'

      - name: Install dependencies
        run: cd shared && mix deps.get

      - name: Run tests
        run: cd shared && mix test

      - name: Run E2E tests
        run: ./scripts/testing/test_all.sh
```

## Test Coverage

### Current Coverage
```
Agents: 85% coverage
Shared Library: 90% coverage
Workflows: 70% coverage
Integration: 60% coverage (growing)
```

### Coverage Goals
- Agents: 90%+
- Shared Library: 95%+
- Workflows: 85%+
- Integration: 80%+

### Generate Coverage Report
```bash
cd shared
mix test --cover
open cover/excoveralls.html
```

## Best Practices

1. **Isolate Tests** - Each test should be independent
2. **Use Fixtures** - Reuse test data from `fixtures/`
3. **Clean State** - Setup/teardown for clean database
4. **Descriptive Names** - Test names should describe behavior
5. **Fast Tests** - Optimize for quick feedback
6. **No Flaky Tests** - Fix intermittent failures immediately

## Debugging Tests

### Failed Test
```bash
# Run with verbose output
mix test --trace test/path/to/test.exs

# Run single test
mix test test/path/to/test.exs:42
```

### Database State
```bash
# Check database during test
psql -U postgres -h localhost -p 5433 -d echo_org_test
```

### Agent Logs
```bash
# View agent logs during E2E test
tail -f logs/ceo.log logs/cto.log
```

## Related Documentation

- **Agent Testing:** [../agents/claude.md](../agents/claude.md)
- **Shared Library:** [../shared/claude.md](../shared/claude.md)
- **CI/CD:** [../.github/workflows/](../.github/workflows/)

---

**Last Updated:** 2025-11-06
**Test Count:** Growing (integration tests being added)
**Framework:** ExUnit + Bash
