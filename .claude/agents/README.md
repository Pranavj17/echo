# Memory MCP Server Agents

This directory contains specialized AI agents for the Memory MCP Server project.

## Available Agents

### 1. code-reviewer 🟢
**Purpose:** Expert code review specialist

**When to use:**
- Immediately after writing or modifying code
- Before committing changes
- During code quality audits

**What it checks:**
- Code simplicity and readability
- Function and variable naming
- Code duplication
- Error handling
- Security (secrets, API keys)
- Input validation
- Test coverage
- Performance considerations

**Metadata:**
- Tools: Read, Grep, Glob, Bash
- Model: inherit
- Color: green

---

### 2. data-scientist 🔵
**Purpose:** Data analysis expert for SQL queries and data insights

**When to use:**
- Analyzing memory storage patterns
- Writing SQL queries for PostgreSQL
- Data insights and reporting
- Query optimization

**Capabilities:**
- Write efficient SQL queries
- Analyze query results
- Provide data-driven recommendations
- Optimize database performance

**Metadata:**
- Tools: Bash, Read, Write
- Model: sonnet

---

### 3. debugger-agent 🟠
**Purpose:** Debugging specialist for errors and test failures

**When to use:**
- When encountering errors or exceptions
- Test failures and unexpected behavior
- Production issues
- Performance problems

**Debugging process:**
1. Capture error message and stack trace
2. Identify reproduction steps
3. Isolate the failure location
4. Implement minimal fix
5. Verify solution works

**Metadata:**
- Tools: Read, Edit, Bash, Grep, Glob
- Color: orange

---

### 4. teacher-student-trainer 🔴
**Purpose:** AI training system for codebase knowledge

**When to use:**
- Training on Memory MCP Server architecture
- Learning database patterns
- Understanding MCP protocol
- Knowledge evaluation and testing

**Training areas:**
- MCP protocol (JSON-RPC 2.0, tool schemas)
- Database design (PostgreSQL, indexes)
- Storage patterns (CRUD operations)
- Testing strategies
- Performance optimization

**Metadata:**
- Model: sonnet
- Color: red
- Operates autonomously in background

---

## How to Use Agents

### In Claude Desktop

Agents are automatically available when this project is opened in Claude Desktop. Reference them in conversation:

```
"Can you review the code I just wrote?"
→ Triggers code-reviewer agent

"Help me debug this error"
→ Triggers debugger-agent

"Analyze the memory table queries"
→ Triggers data-scientist agent

"Train on the MCP architecture"
→ Triggers teacher-student-trainer agent
```

### Agent Invocation

Agents are invoked proactively by Claude Code based on context and task requirements. You can also explicitly request an agent by name.

---

## Agent Metadata

All agents include frontmatter metadata:

```yaml
---
name: agent-name
description: Brief description
tools: List of available tools
model: sonnet | inherit
color: green | blue | orange | red (optional)
---
```

**Tools available:**
- `Read` - Read files from filesystem
- `Write` - Write files to filesystem
- `Edit` - Edit existing files
- `Bash` - Execute bash commands
- `Grep` - Search file contents
- `Glob` - Find files by pattern

**Model options:**
- `sonnet` - Claude Sonnet model
- `inherit` - Use parent conversation model

---

## Customizing Agents

To modify agent behavior:

1. Edit the agent's `.md` file
2. Update the frontmatter metadata if needed
3. Modify the instructions in the content section
4. Save changes (agents reload automatically)

---

## Best Practices

**For code-reviewer:**
- Run after significant code changes
- Use before git commits
- Focus on security and quality

**For data-scientist:**
- Use for query optimization
- Analyze storage patterns
- Generate reports

**For debugger-agent:**
- Provide full error messages
- Include reproduction steps
- Share relevant code context

**For teacher-student-trainer:**
- Run background training sessions
- Check progress periodically
- Focus on specific knowledge areas

---

## Project Context

These agents are specifically tuned for the Memory MCP Server project:

**Technology Stack:**
- Elixir
- PostgreSQL + Ecto
- JSON-RPC 2.0 over stdio
- MCP (Model Context Protocol)

**Core Components:**
- Memory storage (key-value with tags)
- Database schema (single memories table)
- MCP tools (store, retrieve, search, list, delete)
- Storage module (CRUD operations)

---

## Agent Development

### Creating New Agents

To add a new agent:

1. Create `agent-name.md` in this directory
2. Add frontmatter metadata
3. Write agent instructions
4. Test agent invocation

### Agent Template

```markdown
---
name: my-agent
description: Brief description of agent purpose
tools: Read, Write, Bash
model: sonnet
color: blue
---

You are [agent role].

When invoked:
1. [First step]
2. [Second step]
3. [Third step]

[Additional instructions...]
```

---

## Migration Notes

These agents were imported from the claude_memory project and adapted for the Memory MCP Server:

**Source:** `/Users/pranav/Documents/apps/apps/claude_memory/.claude/agents/`

**Changes made:**
- Updated context to Memory MCP Server
- Removed Clientmaster/Nexus specific references
- Adapted teacher-student-trainer to new codebase
- Maintained all original metadata and functionality

**Original metadata preserved:**
- Agent names
- Tool configurations
- Model selections
- Color schemes
- Core instructions

---

**Last Updated:** 2025-10-15
**Version:** 1.0
**Project:** Memory MCP Server
