# Documentation Snippets

Reusable documentation fragments used across multiple `claude.md` files.

## Purpose

These snippets reduce duplication and ensure consistency across documentation. Instead of repeating the same troubleshooting steps or commands in multiple files, we reference these snippets.

## Available Snippets

| Snippet | Description | Used In |
|---------|-------------|---------|
| `database_troubleshooting.md` | PostgreSQL common issues | CLAUDE.md, apps/echo_shared/claude.md, test/claude.md, docker/claude.md |
| `ollama_troubleshooting.md` | Ollama/LLM common issues | CLAUDE.md, apps/claude.md, scripts/claude.md, benchmark_models/claude.md |
| `testing_commands.md` | Common test commands | CLAUDE.md, test/claude.md, apps/claude.md, training/claude.md |
| `git_workflow.md` | Git best practices | CLAUDE.md, all agent development |

## Usage in claude.md Files

### Option 1: Direct Reference

```markdown
## Troubleshooting

**Database connection issues:** See [docs/snippets/database_troubleshooting.md](../../docs/snippets/database_troubleshooting.md)

**LLM not responding:** See [docs/snippets/ollama_troubleshooting.md](../../docs/snippets/ollama_troubleshooting.md)
```

### Option 2: Quick Summary + Reference

```markdown
## Troubleshooting

**Database connection refused:**
```bash
docker-compose up -d && cd shared && mix ecto.migrate
```

For more database troubleshooting, see [docs/snippets/database_troubleshooting.md](../../docs/snippets/database_troubleshooting.md)
```

### Option 3: Full Inclusion (for critical info)

Include the full snippet content when it's critical for the workflow.

## Benefits

1. **DRY (Don't Repeat Yourself)** - Single source of truth
2. **Consistency** - Same troubleshooting steps everywhere
3. **Maintainability** - Update once, applies everywhere
4. **Token Efficiency** - Reference instead of duplicate (saves tokens in LocalCode bootup)

## Adding New Snippets

1. Identify duplicated content across 3+ claude.md files
2. Create new snippet file in `docs/snippets/`
3. Use descriptive filename: `<topic>_<purpose>.md`
4. Add to this README table
5. Update relevant claude.md files to reference the snippet

## Snippet Guidelines

- **Focused:** Each snippet covers one specific topic
- **Self-contained:** Can be understood without external context
- **Actionable:** Provides concrete commands/solutions
- **Versioned:** Update snippet when commands change
- **Referenced:** Track which files use each snippet

---

**Remember:** Snippets reduce token usage and improve maintainability!
