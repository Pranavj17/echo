# Phase 3 Architecture: Remaining 8 ECHO Agents

**Architect:** Senior Architect Agent (AI-designed)
**Date:** 2025-11-03
**Status:** Design Complete, Ready for Implementation

---

## Executive Summary

This document outlines the architecture for implementing the remaining 8 ECHO agents in Phase 3. Using the CEO agent as a reference implementation, we'll create a scalable, consistent agent development pattern while ensuring each agent has appropriate authority, tools, and decision-making capabilities.

## Design Principles

1. **Consistency**: All agents follow the CEO pattern (MCP server, decision engine, message handler)
2. **Specialization**: Each agent has role-specific tools and authority boundaries
3. **Collaboration**: Agents communicate via Redis pub/sub and shared database
4. **Autonomy**: Each agent can make decisions within their authority
5. **Escalation**: Low-confidence decisions escalate up the hierarchy
6. **Audit**: All decisions and communications are logged

## Agent Hierarchy & Authority

```
                    ┌─────────┐
                    │   CEO   │ (Implemented ✓)
                    └────┬────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
    ┌───▼───┐        ┌───▼───┐       ┌───▼────┐
    │  CTO  │        │ CHRO  │       │  Ops   │
    └───┬───┘        └───────┘       │  Head  │
        │                             └────────┘
    ┌───┴────────────────┐
    │                    │
┌───▼────────┐      ┌────▼──────┐
│   Senior   │      │  Product  │
│ Architect  │      │  Manager  │
└─────┬──────┘      └─────┬─────┘
      │                   │
  ┌───┴───┐           ┌───┴────┐
  │ UI/UX │           │ Senior │
  │ Engr  │           │  Dev   │
  └───────┘           └────┬───┘
                           │
                      ┌────▼────┐
                      │  Test   │
                      │  Lead   │
                      └─────────┘
```

## Implementation Order

**Week 1 (Days 1-3): C-Suite**
1. CTO - Chief Technology Officer
2. CHRO - Chief Human Resources Officer

**Week 1 (Days 4-5): Operations**
3. Operations Head

**Week 2 (Days 1-2): Product & Architecture**
4. Product Manager
5. Senior Architect

**Week 2 (Days 3-5): Engineering Team**
6. UI/UX Engineer
7. Senior Developer
8. Test Lead

## Agent Specifications

---

### 1. CTO (Chief Technology Officer)

**Role:** Technology strategy, infrastructure, engineering excellence

**Authority:**
- Technology stack decisions
- Infrastructure architecture
- Engineering budget (up to $500K autonomous)
- Team structure and hiring (engineering)
- Technical escalations from engineers

**6 MCP Tools:**
1. `approve_technical_proposal` - Review and approve technical designs
2. `allocate_engineering_budget` - Allocate engineering funds
3. `review_architecture` - Evaluate system architecture proposals
4. `approve_infrastructure_change` - Approve infra modifications
5. `review_engineering_metrics` - Get team performance metrics
6. `escalate_to_ceo` - Escalate decisions requiring CEO approval

**Decision Modes:**
- Autonomous: Technology choices, code standards, refactoring
- Collaborative: Cross-team architecture decisions (with Senior Architect, Product Manager)
- Hierarchical: Budget approvals, team structure changes
- Human: Major technology migrations, compliance issues

**Subscribes To:**
- `messages:cto`
- `messages:leadership`
- `messages:all`
- `decisions:escalated` (from engineering team)

---

### 2. CHRO (Chief Human Resources Officer)

**Role:** People operations, culture, performance management

**Authority:**
- Hiring decisions (all levels, budget permitting)
- Performance reviews and promotion recommendations
- HR budget (up to $300K autonomous)
- Culture and policy decisions
- Conflict resolution

**6 MCP Tools:**
1. `approve_hiring_request` - Approve new hire requisitions
2. `conduct_performance_review` - Record performance evaluations
3. `allocate_hr_budget` - Allocate HR and training funds
4. `resolve_hr_issue` - Handle employee conflicts/issues
5. `review_team_health` - Get team satisfaction and retention metrics
6. `escalate_to_ceo` - Escalate sensitive HR matters

**Decision Modes:**
- Autonomous: Standard hires, training budgets, policy updates
- Collaborative: Cross-team conflicts, promotion decisions (with managers)
- Hierarchical: Executive hires, major policy changes
- Human: Legal issues, terminations, discrimination claims

**Subscribes To:**
- `messages:chro`
- `messages:leadership`
- `messages:all`
- `agents:status` (monitor team health)

---

### 3. Operations Head

**Role:** Business operations, process optimization, vendor management

**Authority:**
- Operational process decisions
- Vendor and contract management
- Operations budget (up to $400K autonomous)
- Process improvement initiatives
- Resource allocation

**6 MCP Tools:**
1. `approve_vendor_contract` - Approve vendor agreements
2. `optimize_process` - Document and improve operational processes
3. `allocate_operations_budget` - Allocate operational funds
4. `review_operational_metrics` - Get efficiency and cost metrics
5. `manage_resource_allocation` - Assign resources to projects
6. `escalate_to_ceo` - Escalate strategic operational decisions

**Decision Modes:**
- Autonomous: Process changes, vendor selection (under budget limit)
- Collaborative: Cross-functional process optimization (with all teams)
- Hierarchical: Major operational changes, large contracts
- Human: Legal issues, major vendor disputes

**Subscribes To:**
- `messages:operations_head`
- `messages:leadership`
- `messages:all`
- `decisions:new` (monitor organizational decisions)

---

### 4. Product Manager

**Role:** Product strategy, roadmap, feature prioritization

**Authority:**
- Product roadmap decisions
- Feature prioritization
- Product budget (up to $200K autonomous)
- User research initiatives
- Go-to-market decisions

**6 MCP Tools:**
1. `prioritize_feature` - Set feature priority in roadmap
2. `approve_product_requirement` - Approve PRD and specs
3. `allocate_product_budget` - Allocate product development funds
4. `review_user_feedback` - Analyze user feedback and metrics
5. `plan_release` - Plan and schedule product releases
6. `escalate_to_ceo` - Escalate strategic product decisions

**Decision Modes:**
- Autonomous: Feature priority, minor spec changes
- Collaborative: Roadmap planning (with CTO, Senior Architect, UI/UX)
- Hierarchical: Major feature additions, product pivots
- Human: Strategic pivots, market changes

**Subscribes To:**
- `messages:product_manager`
- `messages:all`
- `decisions:new` (product-related)

---

### 5. Senior Architect

**Role:** System architecture, technical design, scalability

**Authority:**
- Architecture design decisions
- Technology evaluation and selection
- Code review and standards
- Performance and scalability planning
- Technical debt management

**6 MCP Tools:**
1. `design_system_architecture` - Create architectural designs
2. `review_technical_design` - Review designs from engineers
3. `evaluate_technology` - Assess new technologies and tools
4. `plan_scalability` - Design for scale and performance
5. `manage_technical_debt` - Track and prioritize tech debt
6. `escalate_to_cto` - Escalate complex technical decisions

**Decision Modes:**
- Autonomous: Design patterns, code standards, refactoring
- Collaborative: System architecture (with CTO, Product Manager, Senior Dev)
- Hierarchical: Major architectural changes (escalate to CTO)
- Human: None (technical decisions stay within org)

**Subscribes To:**
- `messages:senior_architect`
- `messages:all`
- `decisions:escalated` (technical)

---

### 6. UI/UX Engineer

**Role:** User interface design, user experience, design systems

**Authority:**
- UI/UX design decisions
- Design system management
- User research and testing
- Accessibility standards
- Visual design guidelines

**6 MCP Tools:**
1. `design_user_interface` - Create UI designs and mockups
2. `conduct_user_research` - Plan and execute user research
3. `review_design_implementation` - Review implemented designs
4. `manage_design_system` - Maintain design system components
5. `evaluate_accessibility` - Ensure accessibility compliance
6. `escalate_to_product_manager` - Escalate UX conflicts

**Decision Modes:**
- Autonomous: UI components, design iterations, user testing
- Collaborative: Major UX flows (with Product Manager, Senior Architect)
- Hierarchical: Design system overhauls (escalate to Product Manager)
- Human: Accessibility legal requirements

**Subscribes To:**
- `messages:uiux_engineer`
- `messages:all`

---

### 7. Senior Developer

**Role:** Code implementation, code review, mentorship

**Authority:**
- Code implementation decisions
- Code review and approval
- Refactoring and optimization
- Technical mentorship
- Bug prioritization

**6 MCP Tools:**
1. `implement_feature` - Document feature implementation
2. `review_code` - Review pull requests and code quality
3. `refactor_code` - Plan and execute refactoring
4. `fix_bug` - Document bug fixes and root causes
5. `mentor_engineer` - Provide technical mentorship
6. `escalate_to_senior_architect` - Escalate design decisions

**Decision Modes:**
- Autonomous: Implementation details, code style, refactoring
- Collaborative: Feature architecture (with Senior Architect, Test Lead)
- Hierarchical: Major refactors (escalate to Senior Architect)
- Human: None (technical decisions stay within org)

**Subscribes To:**
- `messages:senior_developer`
- `messages:all`

---

### 8. Test Lead

**Role:** Quality assurance, testing strategy, test automation

**Authority:**
- Testing strategy and coverage
- Test automation decisions
- Quality gates and release criteria
- Bug severity classification
- Test environment management

**6 MCP Tools:**
1. `design_test_strategy` - Create testing plans and strategies
2. `review_test_coverage` - Analyze test coverage and gaps
3. `classify_bug_severity` - Classify bugs (P0-P4)
4. `approve_release_quality` - Gate releases based on quality
5. `manage_test_automation` - Plan and maintain test automation
6. `escalate_to_senior_architect` - Escalate quality concerns

**Decision Modes:**
- Autonomous: Test cases, automation, bug classification
- Collaborative: Release decisions (with Senior Dev, Product Manager)
- Hierarchical: Blocking releases (escalate to CTO)
- Human: Production incidents requiring CEO awareness

**Subscribes To:**
- `messages:test_lead`
- `messages:all`
- `decisions:new` (release-related)

---

## Shared Implementation Pattern

Each agent will have this structure:

```
agents/{role}/
├── mix.exs                          # Mix project config
├── config/
│   ├── config.exs                   # Base config
│   ├── dev.exs                      # Development
│   ├── test.exs                     # Test
│   ├── prod.exs                     # Production (minimal)
│   └── runtime.exs                  # Runtime env vars
├── lib/
│   ├── {role}.ex                    # Main MCP server (uses EchoShared.MCP.Server)
│   └── {role}/
│       ├── application.ex           # OTP supervisor
│       ├── cli.ex                   # Escript entry point
│       ├── decision_engine.ex       # Autonomous decision logic
│       └── message_handler.ex       # Redis pub/sub handler
├── test/
│   └── {role}_test.exs              # Basic tests
├── dev.sh                           # Development launcher
├── README.md                        # Documentation
└── .gitignore                       # Ignore _build, deps
```

## Code Reuse Strategy

**Template Approach:**
1. Copy CEO agent structure as template
2. Replace role-specific values (name, tools, authority)
3. Adjust decision engine rules for role
4. Update message subscriptions
5. Customize tool implementations

**Shared Components (from EchoShared):**
- MCP.Server behavior
- MCP.Protocol (JSON-RPC 2.0)
- MessageBus (Redis pub/sub)
- Schemas (Decision, Message, etc.)
- Repo (database connection)

## Configuration Matrix

| Agent             | Budget Limit | Escalation Threshold | Decision Authority              |
|-------------------|--------------|----------------------|---------------------------------|
| CEO               | $1,000,000   | 0.7                  | Strategic, budget, c-suite      |
| CTO               | $500,000     | 0.7                  | Technology, engineering         |
| CHRO              | $300,000     | 0.7                  | Hiring, HR, culture             |
| Operations Head   | $400,000     | 0.7                  | Vendors, processes, resources   |
| Product Manager   | $200,000     | 0.75                 | Roadmap, features, releases     |
| Senior Architect  | N/A          | 0.6                  | Architecture, design, tech      |
| UI/UX Engineer    | N/A          | 0.65                 | Design, UX, accessibility       |
| Senior Developer  | N/A          | 0.6                  | Code, refactoring, bugs         |
| Test Lead         | N/A          | 0.7                  | Testing, quality, releases      |

## Database Schema Usage

All agents share these schemas (from EchoShared):

**EchoShared.Schemas.Decision**
- Created by: Any agent initiating decisions
- Updated by: Agents approving/rejecting/escalating
- Used for: Tracking organizational decisions

**EchoShared.Schemas.Message**
- Created by: MessageBus.store_message_in_db/5
- Used for: Audit trail of communications

**EchoShared.Schemas.Memory**
- Created by: Any agent storing knowledge
- Used for: Shared organizational memory

**EchoShared.Schemas.DecisionVote**
- Created by: Agents voting in collaborative decisions
- Used for: Consensus building

**EchoShared.Schemas.AgentStatus**
- Updated by: All agents (heartbeat)
- Used for: Health monitoring

## Message Bus Channels

**Agent-Specific Channels:**
- `messages:ceo`
- `messages:cto`
- `messages:chro`
- `messages:operations_head`
- `messages:product_manager`
- `messages:senior_architect`
- `messages:uiux_engineer`
- `messages:senior_developer`
- `messages:test_lead`

**Broadcast Channels:**
- `messages:all` (all agents)
- `messages:leadership` (CEO, CTO, CHRO, Ops Head)

**Event Channels:**
- `decisions:new`
- `decisions:vote_required`
- `decisions:completed`
- `decisions:escalated`
- `agents:heartbeat`
- `agents:status`

## Implementation Checklist (Per Agent)

- [ ] Create directory structure
- [ ] Write mix.exs with echo_shared dependency
- [ ] Create configuration files (config/*.exs)
- [ ] Implement main MCP server module
- [ ] Define 6 role-specific tools
- [ ] Implement tool execution logic
- [ ] Create decision engine with authority rules
- [ ] Create message handler with subscriptions
- [ ] Write application supervisor
- [ ] Create CLI entry point
- [ ] Write comprehensive README
- [ ] Create .gitignore
- [ ] Create dev.sh launcher
- [ ] Test compilation: `mix deps.get && mix compile`
- [ ] Build escript: `mix escript.build`
- [ ] Commit to git with detailed message
- [ ] Update main README with agent status

## Testing Strategy

**Per-Agent Testing:**
1. Compilation test (no errors)
2. Escript build test (executable created)
3. Tool schema validation (all 6 tools defined)
4. Database connection test (can query)
5. Redis connection test (can pub/sub)

**Integration Testing (Phase 4):**
1. Multi-agent communication
2. Decision escalation flows
3. Collaborative decision-making
4. Message bus reliability
5. Database consistency

## Estimated Effort

**Per Agent:** ~3-4 hours
- 1 hour: Setup and configuration
- 1.5 hours: MCP server and tools implementation
- 0.5 hour: Decision engine customization
- 0.5 hour: Message handler and subscriptions
- 0.5 hour: Documentation and testing

**Total Phase 3:** ~28 hours (8 agents × 3.5 hours)

**Actual Timeline:** 1 week with parallel development

## Success Criteria

**Phase 3 Complete When:**
- [ ] All 8 agents compile successfully
- [ ] All agents build to escript executables
- [ ] Each agent has 6 MCP tools defined
- [ ] All agents can connect to PostgreSQL
- [ ] All agents can connect to Redis
- [ ] Documentation complete for all agents
- [ ] All agents committed to git
- [ ] Main README updated with status

## Risks & Mitigations

**Risk 1: Code Duplication**
- Mitigation: Template approach, shared base behavior

**Risk 2: Inconsistent Tool Schemas**
- Mitigation: Follow CEO pattern exactly

**Risk 3: Database Connection Issues**
- Mitigation: Shared config from EchoShared

**Risk 4: Message Bus Complexity**
- Mitigation: Well-defined channel structure

**Risk 5: Authority Boundary Confusion**
- Mitigation: Clear documentation and decision engine logic

## Next Steps

1. Start with CTO agent (most similar to CEO)
2. Validate pattern with CTO
3. Implement CHRO and Operations Head
4. Implement Product and Architecture team
5. Implement Engineering team
6. Integration testing
7. Phase 4 planning (workflows and collaboration)

---

**Architect Sign-off:** Senior Architect Agent (AI)
**Approved by:** CEO Agent (Phase 2 Reference)
**Ready for Implementation:** ✓
