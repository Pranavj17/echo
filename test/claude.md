# test/

**Context:** Integration & End-to-End Testing for ECHO

This directory contains integration tests, end-to-end tests, and test fixtures for the ECHO multi-agent system.

## Purpose

Testing ensures:
- **Integration Testing** - Multi-agent workflows and interactions
- **End-to-End Testing** - Complete system scenarios
- **Regression Testing** - Prevent breaking changes
- **Performance Testing** - Response times and throughput
- **Reliability Testing** - Error handling and recovery

## Directory Structure

```
test/
├── claude.md           # This file
├── integration/        # Multi-agent integration tests
│   ├── autonomous_mode_test.exs
│   ├── collaborative_mode_test.exs
│   ├── hierarchical_mode_test.exs
│   └── human_loop_test.exs
├── e2e/               # End-to-end system tests
│   ├── full_workflow_test.exs
│   ├── decision_flow_test.exs
│   └── escalation_test.exs
└── fixtures/          # Test data and helpers
    ├── decisions.json
    ├── messages.json
    └── test_helpers.ex
```

## Test Organization

### Unit Tests
Located in each component directory:
- `apps/echo_shared/test/` - Shared library tests
- `apps/ceo/test/` - CEO agent tests
- `apps/*/test/` - Individual agent tests

**Run unit tests:**
```bash
# Test shared library
cd apps/echo_shared && mix test

# Test specific agent
cd apps/ceo && mix test

# Test all agents
./scripts/testing/test_all_agents.sh
```

### Integration Tests
Located in `test/integration/` - Multi-agent scenarios

**Purpose:** Test agent-to-agent communication, decision flows, and workflows

**Run integration tests:**
```bash
cd test/integration
mix test

# Run specific test
mix test test/integration/collaborative_mode_test.exs

# Run with specific tag
mix test --only integration
```

### End-to-End Tests
Located in `test/e2e/` - Complete system scenarios

**Purpose:** Test full workflows from initiation to completion

**Run E2E tests:**
```bash
cd test/e2e
mix test

# Run with coverage
mix test --cover

# Run with trace
mix test --trace
```

## Integration Test Patterns

### Pattern 1: Autonomous Decision Test

```elixir
defmodule ECHO.Integration.AutonomousModeTest do
  use ExUnit.Case
  alias EchoShared.{DecisionEngine, MessageBus, Repo}
  alias EchoShared.Schemas.Decision

  setup do
    # Clean database before each test
    Repo.delete_all(Decision)
    :ok
  end

  test "CEO approves budget decision autonomously within authority limit" do
    # 1. Create decision within CEO's authority ($1M)
    {:ok, decision} = DecisionEngine.initiate_decision(
      initiator_role: :ceo,
      mode: :autonomous,
      decision_type: "budget_approval",
      description: "Approve Q1 marketing budget",
      context: %{"amount" => 500_000, "department" => "marketing"}
    )

    # 2. Wait for decision processing
    :timer.sleep(1000)

    # 3. Verify decision was approved autonomously
    decision = Repo.get!(Decision, decision.id)
    assert decision.status == "approved"
    assert decision.mode == :autonomous
    assert decision.approver_role == :ceo
  end

  test "CEO escalates budget decision exceeding authority limit" do
    # 1. Create decision exceeding CEO's authority ($1M)
    {:ok, decision} = DecisionEngine.initiate_decision(
      initiator_role: :ceo,
      mode: :autonomous,
      decision_type: "budget_approval",
      description: "Approve major acquisition",
      context: %{"amount" => 5_000_000, "department" => "corporate"}
    )

    # 2. Wait for escalation processing
    :timer.sleep(1000)

    # 3. Verify decision was escalated to human
    decision = Repo.get!(Decision, decision.id)
    assert decision.status == "pending_human_approval"
    assert decision.mode == :human
    assert decision.escalated_to == :human
  end
end
```

### Pattern 2: Collaborative Decision Test

```elixir
defmodule ECHO.Integration.CollaborativeModeTest do
  use ExUnit.Case
  alias EchoShared.{DecisionEngine, Repo}
  alias EchoShared.Schemas.{Decision, DecisionVote}

  test "Architecture decision requires consensus from CTO, Architect, and Dev" do
    # 1. Initiate collaborative decision
    {:ok, decision} = DecisionEngine.initiate_decision(
      initiator_role: :cto,
      mode: :collaborative,
      decision_type: "architecture_change",
      description: "Migrate to microservices",
      context: %{"current": "monolith", "proposed": "microservices"},
      participants: [:cto, :senior_architect, :senior_developer]
    )

    # 2. Simulate votes from participants
    DecisionEngine.vote(decision.id, :cto, true, "Supports scalability")
    DecisionEngine.vote(decision.id, :senior_architect, true, "Good design")
    DecisionEngine.vote(decision.id, :senior_developer, false, "Complexity concerns")

    # 3. Wait for consensus calculation
    :timer.sleep(500)

    # 4. Verify decision outcome
    decision = Repo.get!(Decision, decision.id) |> Repo.preload(:votes)
    assert length(decision.votes) == 3
    assert decision.consensus_score == 0.67  # 2/3 approved
    assert decision.status == "approved"     # Threshold met
  end
end
```

### Pattern 3: Hierarchical Escalation Test

```elixir
defmodule ECHO.Integration.HierarchicalModeTest do
  use ExUnit.Case
  alias EchoShared.{DecisionEngine, Repo}
  alias EchoShared.Schemas.Decision

  test "Developer decision escalates through hierarchy: Dev -> Architect -> CTO" do
    # 1. Developer initiates decision
    {:ok, decision} = DecisionEngine.initiate_decision(
      initiator_role: :senior_developer,
      mode: :hierarchical,
      decision_type: "implementation_approach",
      description: "Use experimental library",
      context: %{"library": "experimental-lib-v0.1.0"}
    )

    # 2. Developer cannot approve (requires escalation)
    :timer.sleep(500)
    decision = Repo.get!(Decision, decision.id)
    assert decision.escalated_to == :senior_architect

    # 3. Architect escalates to CTO (high risk)
    DecisionEngine.escalate(decision.id, :senior_architect, :cto, "Requires CTO approval")
    :timer.sleep(500)
    decision = Repo.get!(Decision, decision.id)
    assert decision.escalated_to == :cto

    # 4. CTO approves
    DecisionEngine.approve(decision.id, :cto, "Approved for experimentation")
    :timer.sleep(500)
    decision = Repo.get!(Decision, decision.id)
    assert decision.status == "approved"
    assert decision.approver_role == :cto
  end
end
```

### Pattern 4: Message Bus Integration Test

```elixir
defmodule ECHO.Integration.MessageBusTest do
  use ExUnit.Case
  alias EchoShared.MessageBus

  test "CEO sends message to CTO, CTO receives and responds" do
    # 1. Subscribe to channels
    MessageBus.subscribe("messages:cto")
    MessageBus.subscribe("messages:ceo")

    # 2. CEO sends message to CTO
    {:ok, message_id} = MessageBus.send_message(
      from_role: :ceo,
      to_role: :cto,
      type: :request,
      subject: "Architecture review needed",
      content: %{"document_url" => "https://example.com/design.pdf"}
    )

    # 3. CTO receives message (via pub/sub)
    assert_receive {:message, "messages:cto", payload}, 1000
    assert payload.from_role == "ceo"
    assert payload.subject == "Architecture review needed"

    # 4. CTO responds
    {:ok, response_id} = MessageBus.send_message(
      from_role: :cto,
      to_role: :ceo,
      type: :response,
      subject: "Re: Architecture review needed",
      content: %{"status" => "reviewed", "feedback" => "Looks good"},
      in_reply_to: message_id
    )

    # 5. CEO receives response
    assert_receive {:message, "messages:ceo", response_payload}, 1000
    assert response_payload.in_reply_to == message_id
    assert response_payload.content["status"] == "reviewed"
  end
end
```

## End-to-End Test Patterns

### E2E Pattern: Full Decision Workflow

```elixir
defmodule ECHO.E2E.FullWorkflowTest do
  use ExUnit.Case
  alias EchoShared.{DecisionEngine, MessageBus, Repo}

  @moduletag :e2e

  test "Complete workflow: Product Manager proposes feature -> Architecture -> Implementation -> Testing" do
    # 1. PM proposes new feature
    {:ok, decision} = DecisionEngine.initiate_decision(
      initiator_role: :product_manager,
      mode: :collaborative,
      decision_type: "feature_proposal",
      description: "Add user authentication",
      participants: [:product_manager, :senior_architect, :senior_developer, :test_lead]
    )

    # 2. All participants vote
    DecisionEngine.vote(decision.id, :product_manager, true, "High priority")
    DecisionEngine.vote(decision.id, :senior_architect, true, "Will design")
    DecisionEngine.vote(decision.id, :senior_developer, true, "Can implement")
    DecisionEngine.vote(decision.id, :test_lead, true, "Will test")

    # 3. Wait for approval
    :timer.sleep(1000)
    decision = Repo.get!(Decision, decision.id)
    assert decision.status == "approved"

    # 4. Architect creates design decision
    {:ok, design_decision} = DecisionEngine.initiate_decision(
      initiator_role: :senior_architect,
      mode: :collaborative,
      decision_type: "architecture_design",
      description: "OAuth 2.0 + JWT tokens",
      participants: [:senior_architect, :senior_developer, :cto],
      parent_decision_id: decision.id
    )

    # 5. Design gets approved
    DecisionEngine.vote(design_decision.id, :senior_architect, true, "Designed")
    DecisionEngine.vote(design_decision.id, :senior_developer, true, "Agree")
    DecisionEngine.vote(design_decision.id, :cto, true, "Approved")
    :timer.sleep(1000)

    # 6. Developer implements
    {:ok, impl_decision} = DecisionEngine.initiate_decision(
      initiator_role: :senior_developer,
      mode: :autonomous,
      decision_type: "implementation",
      description: "Implement OAuth 2.0",
      parent_decision_id: design_decision.id
    )

    # 7. Test Lead verifies
    {:ok, test_decision} = DecisionEngine.initiate_decision(
      initiator_role: :test_lead,
      mode: :autonomous,
      decision_type: "test_results",
      description: "All auth tests pass",
      parent_decision_id: impl_decision.id
    )

    # 8. Verify complete workflow
    :timer.sleep(1000)
    assert Repo.get!(Decision, decision.id).status == "approved"
    assert Repo.get!(Decision, design_decision.id).status == "approved"
    assert Repo.get!(Decision, impl_decision.id).status == "approved"
    assert Repo.get!(Decision, test_decision.id).status == "approved"
  end
end
```

## Test Fixtures

### Fixtures Pattern

```elixir
# test/fixtures/test_helpers.ex
defmodule ECHO.TestHelpers do
  alias EchoShared.Repo
  alias EchoShared.Schemas.{Decision, Message, Memory}

  def create_decision(attrs \\ %{}) do
    defaults = %{
      initiator_role: :ceo,
      mode: :autonomous,
      decision_type: "test_decision",
      description: "Test decision",
      status: "pending",
      context: %{}
    }

    attrs = Map.merge(defaults, attrs)
    %Decision{}
    |> Decision.changeset(attrs)
    |> Repo.insert!()
  end

  def create_message(attrs \\ %{}) do
    defaults = %{
      from_role: :ceo,
      to_role: :cto,
      type: :info,
      subject: "Test message",
      content: %{},
      read: false
    }

    attrs = Map.merge(defaults, attrs)
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert!()
  end

  def create_memory(attrs \\ %{}) do
    defaults = %{
      role: :ceo,
      key: "test_key",
      value: %{"data" => "test"},
      tags: ["test"]
    }

    attrs = Map.merge(defaults, attrs)
    %Memory{}
    |> Memory.changeset(attrs)
    |> Repo.insert!()
  end

  def clean_database() do
    Repo.delete_all(Decision)
    Repo.delete_all(Message)
    Repo.delete_all(Memory)
  end
end
```

### Using Fixtures in Tests

```elixir
defmodule ECHO.Integration.SomeTest do
  use ExUnit.Case
  import ECHO.TestHelpers

  setup do
    clean_database()
    :ok
  end

  test "using fixtures" do
    decision = create_decision(%{
      initiator_role: :ceo,
      decision_type: "budget_approval"
    })

    message = create_message(%{
      from_role: :ceo,
      to_role: :cto,
      subject: "Review decision #{decision.id}"
    })

    assert decision.initiator_role == :ceo
    assert message.subject =~ "Review decision"
  end
end
```

## Running Tests

### All Tests
```bash
# From project root
mix test

# With coverage
mix test --cover

# Parallel execution
mix test --max-cases 4
```

### Specific Tests
```bash
# Integration tests only
mix test test/integration/

# E2E tests only
mix test test/e2e/

# Specific test file
mix test test/integration/autonomous_mode_test.exs

# Specific test by line number
mix test test/integration/autonomous_mode_test.exs:15
```

### Tagged Tests
```bash
# Run only integration tests
mix test --only integration

# Run only E2E tests
mix test --only e2e

# Exclude slow tests
mix test --exclude slow

# Run only fast tests
mix test --only fast
```

## Test Configuration

### test/test_helper.exs
```elixir
ExUnit.start()

# Set test environment
Application.put_env(:echo_shared, :env, :test)

# Start test database
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

# Configure test database
Application.put_env(:echo_shared, EchoShared.Repo,
  database: "echo_org_test",
  pool: Ecto.Adapters.SQL.Sandbox
)

# Start Repo
{:ok, _} = EchoShared.Repo.start_link()

# Configure Ecto sandbox
Ecto.Adapters.SQL.Sandbox.mode(EchoShared.Repo, :manual)
```

### Test Database Setup
```bash
# Create test database
PGPASSWORD=postgres psql -h localhost -p 5433 -U echo_org -c "CREATE DATABASE echo_org_test"

# Run migrations
cd apps/echo_shared
MIX_ENV=test mix ecto.migrate

# Reset test database
MIX_ENV=test mix ecto.reset
```

## Performance Testing

### Load Test Pattern
```elixir
defmodule ECHO.Performance.LoadTest do
  use ExUnit.Case

  @moduletag :performance
  @moduletag timeout: :infinity

  test "system handles 1000 concurrent decisions" do
    # Start timer
    start_time = System.monotonic_time(:millisecond)

    # Create 1000 decisions in parallel
    tasks = for i <- 1..1000 do
      Task.async(fn ->
        DecisionEngine.initiate_decision(
          initiator_role: :ceo,
          mode: :autonomous,
          decision_type: "load_test",
          description: "Load test decision #{i}"
        )
      end)
    end

    # Wait for all to complete
    results = Task.await_many(tasks, 30_000)

    # Calculate metrics
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    throughput = 1000 / (duration / 1000)

    # Verify all succeeded
    assert length(results) == 1000
    assert Enum.all?(results, fn {:ok, _} -> true; _ -> false end)

    # Log metrics
    IO.puts("Duration: #{duration}ms")
    IO.puts("Throughput: #{throughput} decisions/sec")
    assert throughput > 50  # Minimum 50 decisions/sec
  end
end
```

## Troubleshooting Tests

### Database Issues
```bash
# Test database not found
PGPASSWORD=postgres psql -h localhost -p 5433 -U echo_org -c "CREATE DATABASE echo_org_test"

# Stale connections
MIX_ENV=test mix ecto.reset

# Permission issues
GRANT ALL PRIVILEGES ON DATABASE echo_org_test TO echo_org;
```

### Timeout Issues
```bash
# Increase test timeout
mix test --timeout 60000

# Or in specific test
@moduletag timeout: 60_000
```

### Flaky Tests
```elixir
# Add retries for flaky tests
test "flaky test" do
  Enum.find_value(1..3, fn attempt ->
    try do
      # Test code here
      :ok
    rescue
      _ -> if attempt == 3, do: reraise, else: nil
    end
  end)
end
```

## Best Practices

1. **Clean State** - Always clean database in `setup`
2. **Use Fixtures** - DRY principle with test helpers
3. **Tag Tests** - Use `@moduletag` for organization
4. **Async When Possible** - Use `use ExUnit.Case, async: true` for unit tests
5. **Meaningful Assertions** - Use descriptive assertion messages
6. **Test Edge Cases** - Error conditions, boundaries, edge cases
7. **Mock External Services** - Don't depend on Ollama/external APIs in tests
8. **Fast Tests** - Unit tests should be <1s, integration <5s, E2E <30s
9. **Document Test Intent** - Clear test names and comments

## Related Documentation

- **Parent:** [../CLAUDE.md](../CLAUDE.md) - Project overview
- **Shared Library:** [../apps/echo_shared/claude.md](../apps/echo_shared/claude.md) - Testing shared components
- **Agents:** [../apps/claude.md](../apps/claude.md) - Agent testing patterns

---

**Remember:** Tests are documentation. Write them clearly and keep them fast.
