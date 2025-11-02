# Phase 4 Architecture: Workflows & Integration

**Architect:** Senior Architect Agent (AI-designed)
**Date:** 2025-11-03
**Status:** Design Complete, Ready for Implementation

---

## Executive Summary

Phase 4 focuses on integrating the 9 ECHO agents through collaborative workflows, decision-making patterns, and real-time communication. This phase brings the organizational model to life by enabling agents to work together on complex, multi-step tasks.

## Design Principles

1. **Autonomous First**: Each agent makes decisions within their authority independently
2. **Escalate When Needed**: Low-confidence or out-of-scope decisions escalate appropriately
3. **Collaborate Intentionally**: Multi-agent workflows for cross-functional decisions
4. **Audit Everything**: Complete trail of all decisions and communications
5. **Real-time Communication**: Redis pub/sub for immediate agent coordination

## Phase 4 Components

### 1. Workflow Engine

**Purpose:** Orchestrate multi-agent workflows for complex organizational tasks

**Location:** `shared/lib/echo_shared/workflow/`

**Key Modules:**
- `workflow_engine.ex` - Orchestrates multi-step workflows
- `workflow_definition.ex` - Schema for workflow definitions
- `workflow_execution.ex` - Tracks workflow state and progress
- `workflow_step.ex` - Individual step execution logic

**Workflow Types:**
1. **Sequential** - Steps execute in order (Step 1 → Step 2 → Step 3)
2. **Parallel** - Steps execute simultaneously (All at once, wait for all)
3. **Conditional** - Steps execute based on previous outcomes
4. **Human-in-the-Loop** - Pause for human approval/input

### 2. Decision Patterns

**Four decision-making modes** (already defined in architecture):

#### A. Autonomous Mode
- Single agent makes decision within authority
- No collaboration needed
- Example: CTO approves technical proposal under $500K

```elixir
# CTO autonomously approves infrastructure change
decision = %{
  type: "infrastructure_change",
  initiator: :cto,
  mode: :autonomous,
  context: %{change: "Add Redis cache"},
  confidence: 0.85  # Above 0.7 threshold
}
```

#### B. Collaborative Mode
- Multiple agents contribute to decision
- Consensus or majority vote
- Example: Product roadmap planning (Product Manager + CTO + Senior Architect)

```elixir
# Collaborative decision workflow
workflow = %{
  name: "product_roadmap_planning",
  participants: [:product_manager, :cto, :senior_architect],
  mode: :collaborative,
  steps: [
    {:gather_input, :all},
    {:discuss_tradeoffs, :all},
    {:vote, :all},
    {:finalize, :product_manager}
  ]
}
```

#### C. Hierarchical Mode
- Decision escalates up reporting chain
- CEO → C-Suite → Managers → Engineers
- Example: Budget exceeds authority limit

```elixir
# CTO budget request escalates to CEO
decision = %{
  type: "engineering_budget",
  initiator: :cto,
  amount: 750_000,  # Exceeds $500K limit
  mode: :hierarchical,
  escalate_to: :ceo
}
```

#### D. Human-in-the-Loop Mode
- AI agent pauses for human decision
- Used for: Legal, ethical, strategic pivots
- Example: Layoff decision, major acquisition

```elixir
# CHRO escalates termination decision to human
decision = %{
  type: "employee_termination",
  initiator: :chro,
  mode: :human,
  reason: "Legal risk requires human judgment",
  urgency: :high
}
```

### 3. Example Workflows

#### Workflow 1: New Feature Development
**Participants:** Product Manager, Senior Architect, Senior Developer, UI/UX Engineer, Test Lead

**Steps:**
1. **Product Manager** - Creates feature requirement
2. **Senior Architect** - Reviews technical feasibility
3. **UI/UX Engineer** - Designs user interface
4. **Product Manager** - Approves design
5. **Senior Developer** - Implements feature
6. **Test Lead** - Validates quality
7. **Product Manager** - Approves release

**Decision Points:**
- Architecture review: Collaborative (PM + Architect)
- Design approval: Autonomous (PM)
- Code review: Autonomous (Senior Dev)
- Release gate: Autonomous (Test Lead)

#### Workflow 2: Hiring New Engineer
**Participants:** CHRO, CTO, Senior Architect

**Steps:**
1. **CTO** - Identifies need, creates requisition
2. **CHRO** - Reviews against budget and headcount
3. **CHRO** - Approves or escalates to CEO
4. **CHRO** - Posts job and screens candidates
5. **CTO + Senior Architect** - Technical interviews
6. **CHRO** - Makes offer decision

**Decision Points:**
- Budget approval: Autonomous (CHRO if <$300K) or Hierarchical (CEO if >$300K)
- Technical evaluation: Collaborative (CTO + Architect)
- Final offer: Autonomous (CHRO)

#### Workflow 3: Infrastructure Migration
**Participants:** CTO, Operations Head, Senior Architect, Senior Developer

**Steps:**
1. **Senior Architect** - Proposes migration plan
2. **CTO** - Reviews technical approach
3. **Operations Head** - Assesses operational impact
4. **CTO** - Approves or escalates based on cost
5. **Senior Developer** - Executes migration
6. **Operations Head** - Validates deployment
7. **CTO** - Confirms completion

**Decision Points:**
- Migration approval: Collaborative (CTO + Ops + Architect)
- Budget check: Hierarchical (escalate to CEO if >$500K)
- Go/no-go: Autonomous (CTO)

#### Workflow 4: Crisis Response
**Participants:** CEO, CTO, Operations Head, (others as needed)

**Steps:**
1. **Any Agent** - Detects critical issue
2. **Automatic Escalation** - Notifies CEO, CTO, Ops
3. **CEO** - Convenes crisis meeting (collaborative)
4. **Collaborative Discussion** - All participants propose solutions
5. **CEO** - Makes final decision (autonomous)
6. **Operations Head** - Executes response
7. **CEO** - Monitors resolution

**Decision Points:**
- Crisis declaration: Autonomous (any agent can escalate)
- Response strategy: Collaborative (leadership team)
- Final decision: Autonomous (CEO)
- Execution: Autonomous (Ops Head)

### 4. Communication Patterns

#### A. Direct Messaging
One agent → specific agent

```elixir
MessageBus.publish_message(
  from: :cto,
  to: :senior_architect,
  type: :request,
  subject: "Review Infrastructure Proposal",
  content: %{proposal_id: "infra_001"}
)
```

#### B. Broadcast
One agent → all agents

```elixir
MessageBus.broadcast_message(
  from: :ceo,
  type: :notification,
  subject: "Company All-Hands Announcement",
  content: %{message: "Q4 goals..."}
)
```

#### C. Leadership Channel
One agent → C-suite only (CEO, CTO, CHRO, Ops Head)

```elixir
MessageBus.publish_to_channel(
  from: :chro,
  channel: "messages:leadership",
  type: :escalation,
  subject: "Sensitive HR Issue",
  content: %{issue_id: "hr_042"}
)
```

#### D. Decision Events
Broadcast decision lifecycle events

```elixir
# New decision initiated
MessageBus.publish_decision_event(:new, %{
  decision_id: "dec_123",
  type: "infrastructure_change",
  initiator: :cto
})

# Vote required
MessageBus.publish_decision_event(:vote_required, %{
  decision_id: "dec_123",
  participants: [:cto, :senior_architect, :operations_head]
})

# Decision completed
MessageBus.publish_decision_event(:completed, %{
  decision_id: "dec_123",
  outcome: :approved
})
```

### 5. Integration Testing Strategy

#### Unit Tests (Per Agent)
- Tool execution correctness
- Input validation
- Error handling
- Database operations

#### Integration Tests (Multi-Agent)
1. **Direct Communication Test**
   - CTO sends message to Senior Architect
   - Verify message received and acknowledged

2. **Collaborative Decision Test**
   - Product Manager initiates feature decision
   - CTO, Senior Architect participate
   - Verify all votes recorded
   - Verify final decision

3. **Hierarchical Escalation Test**
   - CTO requests $750K budget
   - Verify escalation to CEO
   - CEO approves
   - Verify CTO notified

4. **Workflow Execution Test**
   - Execute "New Feature Development" workflow
   - Verify all steps complete
   - Verify all agents participated
   - Verify final outcome recorded

#### System Tests (Full Stack)
1. **Load Test**
   - 100 concurrent decisions
   - Verify no message loss
   - Verify database consistency

2. **Failover Test**
   - Kill one agent mid-workflow
   - Verify workflow pauses
   - Restart agent
   - Verify workflow resumes

3. **Audit Trail Test**
   - Execute complex workflow
   - Verify all decisions logged
   - Verify all messages stored
   - Verify timeline accurate

### 6. Implementation Plan

#### Week 1: Workflow Engine Foundation
**Days 1-2: Core Engine**
- Implement WorkflowEngine GenServer
- Add workflow definition schema
- Create workflow execution tracker
- Support sequential steps

**Days 3-4: Advanced Patterns**
- Add parallel execution
- Add conditional branching
- Add human-in-the-loop pauses
- Implement timeouts

**Day 5: Testing**
- Unit tests for workflow engine
- Simple sequential workflow test
- Documentation

#### Week 2: Example Workflows
**Days 1-2: Feature Development Workflow**
- Define workflow steps
- Implement step handlers
- Test with real agents
- Document usage

**Days 3-4: Hiring & Infrastructure Workflows**
- Implement hiring workflow
- Implement infrastructure workflow
- Test escalation paths
- Document decision points

**Day 5: Crisis Response**
- Implement crisis workflow
- Test emergency escalation
- Validate CEO override capabilities
- Documentation

#### Week 3: Integration Testing
**Days 1-2: Communication Tests**
- Direct messaging tests
- Broadcast tests
- Leadership channel tests
- Decision event tests

**Days 3-4: Workflow Tests**
- End-to-end workflow tests
- Multi-agent collaboration tests
- Escalation path tests
- Error handling tests

**Day 5: System Tests**
- Load testing
- Failover testing
- Audit trail validation
- Performance optimization

#### Week 4: Documentation & Polish
**Days 1-2: User Documentation**
- Workflow authoring guide
- Decision pattern guide
- Integration guide for new agents
- Troubleshooting guide

**Days 3-4: Example Workflows**
- 10+ workflow examples
- Decision pattern examples
- Communication pattern examples
- Best practices guide

**Day 5: Phase 4 Completion**
- Final testing
- Documentation review
- Demo workflows
- Phase 4 report

### 7. File Structure

```
echo/
├── shared/
│   └── lib/
│       └── echo_shared/
│           ├── workflow/
│           │   ├── engine.ex              # Core workflow orchestrator
│           │   ├── definition.ex          # Workflow schema
│           │   ├── execution.ex           # Execution state tracker
│           │   ├── step.ex                # Individual step logic
│           │   └── patterns/              # Pre-built patterns
│           │       ├── sequential.ex
│           │       ├── parallel.ex
│           │       ├── conditional.ex
│           │       └── human_loop.ex
│           └── integration/
│               └── test_helpers.ex        # Test utilities
├── workflows/
│   ├── examples/
│   │   ├── feature_development.exs       # Feature workflow
│   │   ├── hiring.exs                    # Hiring workflow
│   │   ├── infrastructure.exs            # Infrastructure workflow
│   │   ├── crisis_response.exs           # Crisis workflow
│   │   └── budget_approval.exs           # Budget workflow
│   └── templates/
│       ├── collaborative.exs             # Template for collaboration
│       ├── hierarchical.exs              # Template for escalation
│       └── autonomous.exs                # Template for single-agent
├── test/
│   ├── integration/
│   │   ├── communication_test.exs        # Message passing tests
│   │   ├── workflow_test.exs             # Workflow execution tests
│   │   ├── decision_test.exs             # Decision pattern tests
│   │   └── escalation_test.exs           # Escalation tests
│   └── system/
│       ├── load_test.exs                 # Load testing
│       ├── failover_test.exs             # Failover testing
│       └── audit_test.exs                # Audit trail tests
└── docs/
    ├── workflows_guide.md                # How to create workflows
    ├── decision_patterns.md              # Decision pattern guide
    ├── integration_guide.md              # Integration guide
    └── phase_4_report.md                 # Final report
```

### 8. Success Criteria

Phase 4 is complete when:

- [ ] Workflow engine implemented and tested
- [ ] At least 5 example workflows working
- [ ] All 4 decision patterns demonstrated
- [ ] Integration tests passing (>90% coverage)
- [ ] System tests passing (load, failover, audit)
- [ ] Documentation complete and reviewed
- [ ] Demo workflows executable via Claude Desktop

### 9. Risks & Mitigations

**Risk 1: Message Bus Complexity**
- Mitigation: Start with simple point-to-point messaging
- Mitigation: Add broadcast/channels incrementally
- Mitigation: Extensive logging for debugging

**Risk 2: Workflow State Management**
- Mitigation: Use database for persistence
- Mitigation: Implement idempotent steps
- Mitigation: Add workflow recovery mechanisms

**Risk 3: Agent Coordination Deadlocks**
- Mitigation: Implement timeouts on all blocking operations
- Mitigation: Add circuit breakers for failed agents
- Mitigation: Human override capability (CEO)

**Risk 4: Testing Complexity**
- Mitigation: Start with unit tests per component
- Mitigation: Build up to integration tests
- Mitigation: Use test fixtures for repeatability

### 10. Demo Scenarios

**Scenario 1: Simple Autonomous Decision**
```
1. User asks CTO: "Approve this technical proposal"
2. CTO uses approve_technical_proposal tool
3. Decision recorded in database
4. Relevant teams notified via message bus
5. Result displayed to user
```

**Scenario 2: Collaborative Decision**
```
1. User asks Product Manager: "Plan Q1 roadmap"
2. PM initiates collaborative workflow
3. PM, CTO, Senior Architect invited to participate
4. Each agent provides input via tools
5. PM synthesizes and finalizes decision
6. Result stored and broadcast
```

**Scenario 3: Hierarchical Escalation**
```
1. User asks CTO: "Allocate $750K for infrastructure"
2. CTO detects amount exceeds authority ($500K)
3. CTO escalates to CEO
4. CEO reviews and approves
5. CTO notified of approval
6. Budget allocated
```

**Scenario 4: Multi-Agent Workflow**
```
1. User asks: "Let's build a new user dashboard feature"
2. PM creates feature requirement
3. Senior Architect reviews feasibility
4. UI/UX designs interface
5. PM approves design
6. Senior Developer implements
7. Test Lead validates quality
8. PM approves release
9. Complete workflow result shown to user
```

---

## Next Steps

1. **Implement Workflow Engine** (Week 1)
2. **Build Example Workflows** (Week 2)
3. **Integration Testing** (Week 3)
4. **Documentation & Demo** (Week 4)

**Architect Sign-off:** Senior Architect Agent (AI)
**Ready for Implementation:** ✓
