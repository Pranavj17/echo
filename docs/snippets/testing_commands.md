# Testing Commands

Common testing commands and patterns for ECHO.

## Unit Tests

```bash
# Test shared library
cd apps/echo_shared && mix test

# Test specific agent
cd apps/ceo && mix test

# Test with coverage
cd apps/ceo && mix test --cover

# Test specific file
cd apps/ceo && mix test test/ceo_test.exs

# Test specific line
cd apps/ceo && mix test test/ceo_test.exs:15
```

## Integration Tests

```bash
# All integration tests
mix test test/integration/

# Specific integration test
mix test test/integration/autonomous_mode_test.exs

# With tags
mix test --only integration
```

## End-to-End Tests

```bash
# All E2E tests
mix test test/e2e/

# Tagged E2E tests
mix test --only e2e

# Exclude slow tests
mix test --exclude slow
```

## All Tests

```bash
# From project root
mix test

# Parallel execution
mix test --max-cases 4

# With trace (detailed output)
mix test --trace
```

## Agent-Specific Tests

```bash
# Test all agents
./scripts/testing/test_all_agents.sh

# Test agent compilation
cd apps/ceo && mix compile --warnings-as-errors

# Test agent LLM integration
./scripts/agents/test_agent_llm.sh ceo

# Test agent autonomous mode
cd apps/ceo && ./ceo --autonomous &
# ... test agent behavior ...
pkill -f ceo
```

## Test Database

```bash
# Create test database
PGPASSWORD=postgres psql -h localhost -p 5433 -U echo_org -c "CREATE DATABASE echo_org_test"

# Run migrations
cd apps/echo_shared && MIX_ENV=test mix ecto.migrate

# Reset test database
cd apps/echo_shared && MIX_ENV=test mix ecto.reset
```

## Continuous Testing

```bash
# Watch mode (re-run on file changes)
mix test.watch

# Or use:
fswatch -o lib/ test/ | xargs -n1 -I{} mix test
```

**Used in:**
- CLAUDE.md (Quick Start section)
- test/claude.md (complete testing guide)
- apps/claude.md (agent testing)
- training/claude.md
