# Git Workflow

Git best practices and common commands for ECHO development.

## Before Committing

```bash
# 1. Run tests
cd apps/echo_shared && mix test
cd apps/ceo && mix test

# 2. Check git status
git status

# 3. Review changes
git diff

# 4. Check recent commits (for message style)
git log --oneline -5
```

## Creating Commits

```bash
# Stage changes
git add apps/ceo/lib/ceo.ex
git add apps/echo_shared/lib/

# Or stage all
git add -A

# Commit with message
git commit -m "$(cat <<'EOF'
feat: Add budget approval tool to CEO agent

- Implement approve_budget tool with authority limits
- Add validation for budget amounts
- Integrate with DecisionEngine for escalation
- Add tests for autonomous and escalation flows

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

## Commit Message Format

```
<type>: <subject>

<body>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `refactor:` - Code refactoring
- `docs:` - Documentation changes
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

## Creating Pull Requests

```bash
# 1. Create and switch to new branch
git checkout -b feature/budget-approval

# 2. Make changes and commit
# ... development ...
git add -A
git commit -m "..."

# 3. Push to remote
git push -u origin feature/budget-approval

# 4. Create PR using gh CLI
gh pr create --title "feat: Add budget approval tool" --body "$(cat <<'EOF'
## Summary
- Implement budget approval tool for CEO agent
- Add authority limits ($1M autonomous, >$1M escalate)
- Include comprehensive test coverage

## Test plan
- [x] Unit tests for approve_budget tool
- [x] Integration tests for decision flow
- [x] Manual testing in autonomous mode

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## Common Commands

```bash
# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo changes to file
git checkout -- file.ex

# Stash changes
git stash
git stash pop

# View commit history
git log --oneline --graph --all

# Show changes in commit
git show <commit-hash>

# Amend last commit (ONLY if not pushed)
git commit --amend

# Pull latest changes
git pull origin main

# Rebase on main
git fetch origin
git rebase origin/main
```

## Pre-commit Hooks

If you get pre-commit hook failures:

```bash
# Fix formatting
mix format

# Fix Credo warnings
mix credo --strict

# Run tests
mix test

# Retry commit
git commit -m "..."
```

## Safety Guidelines

- ✅ **DO** run tests before committing
- ✅ **DO** write descriptive commit messages
- ✅ **DO** use conventional commit format
- ❌ **DON'T** force push to main/master
- ❌ **DON'T** commit secrets or credentials
- ❌ **DON'T** commit large binary files
- ❌ **DON'T** amend pushed commits (unless alone on branch)

**Used in:**
- CLAUDE.md (Git workflow section)
- All agent development
- scripts/claude.md
