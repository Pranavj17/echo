# Agents Directory

**Path:** `/Users/pranav/Documents/memory/.claude/agents/`

## Purpose

This directory contains specialized AI agents for the Memory MCP Server project. These agents provide expert assistance in specific domains such as code review, debugging, data analysis, and training.

## Agents Overview

### 1. code-reviewer.md 🟢
- **Role:** Senior code reviewer
- **Tools:** Read, Grep, Glob, Bash
- **Model:** inherit
- **Use:** Immediately after writing/modifying code
- **Focus:** Quality, security, maintainability
- **Lines:** 31

### 2. data-scientist.md 🔵
- **Role:** Data analysis expert
- **Tools:** Bash, Read, Write
- **Model:** sonnet
- **Use:** SQL queries, data insights, query optimization
- **Focus:** PostgreSQL analysis, performance
- **Lines:** 30

### 3. debugger-agent.md 🟠
- **Role:** Debugging specialist
- **Tools:** Read, Edit, Bash, Grep, Glob
- **Model:** inherit
- **Use:** Errors, test failures, unexpected behavior
- **Focus:** Root cause analysis, minimal fixes
- **Lines:** 31

### 4. teacher-student-trainer.md 🔴
- **Role:** AI training orchestrator
- **Tools:** All (background agent)
- **Model:** sonnet
- **Use:** Background training sessions, knowledge evaluation
- **Focus:** MCP architecture, database patterns, storage
- **Lines:** 186

### 5. README.md 📘
- **Documentation:** Complete agent guide
- **Content:** Usage examples, best practices, metadata
- **Lines:** 262

---

## Agent Metadata Schema

All agents follow this frontmatter structure:

```yaml
---
name: agent-name                # Agent identifier
description: Brief description  # What the agent does
tools: Read, Write, Bash        # Available tools
model: sonnet | inherit         # Model to use
color: green | blue | orange    # Optional color coding
---
```

---

## How Agents Work

### Invocation
Agents are automatically invoked by Claude Code based on:
- Context and task requirements
- Explicit user requests
- Proactive triggers (e.g., after code changes)

### Execution
1. Agent receives context and task
2. Uses specified tools to complete work
3. Returns results and recommendations
4. Updates project state if needed

### Background Agents
Some agents (e.g., teacher-student-trainer) run in background:
- Non-blocking operation
- Persistent state across sessions
- Results surfaced when queried

---

## Migration Details

**Source:** `/Users/pranav/Documents/apps/apps/claude_memory/.claude/agents/`
**Date:** 2025-10-15
**Agents imported:** 4 (from 16 available)

### Selection Criteria
Imported agents specifically useful for Memory MCP Server:
- ✅ **code-reviewer** - Code quality essential for MCP server
- ✅ **data-scientist** - PostgreSQL analysis and optimization
- ✅ **debugger-agent** - Error handling and troubleshooting
- ✅ **teacher-student-trainer** - Learn system architecture

### Not Imported (12 agents)
Skipped agents specific to other projects:
- ❌ ai-agent-trainer - Claude Memory specific
- ❌ asana-task-reader - External integration
- ❌ blog-research-agent - Not relevant
- ❌ debug-memory-agent - Claude Memory specific
- ❌ dream-architect - Development tool
- ❌ git-rebase-pusher - Git automation
- ❌ google-sheet-analyzer - External tool
- ❌ memory-cleanup-architect - Claude Memory specific
- ❌ memory-delegator - Claude Memory specific
- ❌ memory-updater - Claude Memory specific
- ❌ ui-fix - UI specific
- ❌ update-credentials-agent - Security automation

---

## Adaptations Made

### teacher-student-trainer.md
**Original context:** Clientmaster, Nexus, dual databases
**New context:** Memory MCP Server, PostgreSQL, MCP protocol

**Changes:**
- Removed Clientmaster/Nexus references
- Updated training topics to MCP architecture
- Adapted curriculum to single-table design
- Focused on JSON-RPC 2.0 and stdio
- Maintained all scoring and evaluation systems

**Preserved:**
- Dual-persona framework (teacher + student)
- Scoring system (0-100, 4 categories)
- Token limits (8K max)
- Background execution mode
- Progress tracking
- Session management

### Other Agents
**Minimal changes:** Only updated project context references
**Preserved:** All original functionality and metadata

---

## Usage Examples

### Code Review
```
user: "Review the storage module I just wrote"
→ code-reviewer agent activates
→ Analyzes code quality, security, patterns
→ Provides prioritized feedback
```

### Debugging
```
user: "I'm getting an Ecto error when storing memories"
→ debugger-agent activates
→ Analyzes error, checks recent changes
→ Identifies root cause and provides fix
```

### Data Analysis
```
user: "Analyze the most commonly used tags in memories"
→ data-scientist agent activates
→ Writes SQL query
→ Analyzes results
→ Provides insights
```

### Training
```
user: "Train on the MCP protocol architecture"
→ teacher-student-trainer agent activates (background)
→ Runs training session autonomously
→ Reports progress when queried
```

---

## Best Practices

### For Developers
- Use code-reviewer before committing
- Invoke debugger-agent immediately on errors
- Let data-scientist handle complex queries
- Run training sessions periodically

### For Agents
- Follow metadata specifications strictly
- Use only permitted tools
- Maintain token limits
- Provide actionable feedback
- Track progress and state

---

## File Structure

```
.claude/
└── agents/
    ├── CLAUDE.md                      # This file (directory guide)
    ├── README.md                      # User-facing documentation
    ├── code-reviewer.md               # Code review agent
    ├── data-scientist.md              # Data analysis agent
    ├── debugger-agent.md              # Debugging agent
    └── teacher-student-trainer.md     # Training agent
```

---

## Development Guidelines

### Adding New Agents
1. Create `agent-name.md` with frontmatter
2. Define clear role and use cases
3. Specify required tools
4. Write detailed instructions
5. Test agent invocation
6. Update README.md

### Modifying Agents
1. Edit agent `.md` file
2. Update metadata if needed
3. Test changes thoroughly
4. Document modifications
5. Maintain backward compatibility

### Agent Testing
```bash
# Test agent is recognized
cat .claude/agents/agent-name.md

# Verify frontmatter
head -n 10 .claude/agents/agent-name.md

# Check line count
wc -l .claude/agents/*.md
```

---

## Related Documentation

- **Project CLAUDE.md:** `/Users/pranav/Documents/memory/CLAUDE.md`
- **Migration Docs:** `/Users/pranav/Documents/memory/migrations/`
- **Source Agents:** `/Users/pranav/Documents/apps/apps/claude_memory/.claude/agents/`

---

## Summary Statistics

**Total Agents:** 4 operational + 1 README
**Total Lines:** 540 (including documentation)
**Average Size:** 108 lines per agent (excluding README)
**Metadata Complete:** 100%
**Adapted for Project:** 100%

**Agent Distribution:**
- Code Quality: 1 agent (code-reviewer)
- Debugging: 1 agent (debugger-agent)
- Data Analysis: 1 agent (data-scientist)
- Training: 1 agent (teacher-student-trainer)

---

**Last Updated:** 2025-10-15
**Version:** 1.0
**Maintained By:** Memory MCP Server Team
