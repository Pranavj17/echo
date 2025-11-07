# Echo Repository Cleanup List

**Generated:** 2025-11-05
**Purpose:** List of deprecated files to be deleted after distributed context implementation

## 🗑️ Files to Delete

### Category 1: Temporary Fix/Summary Documents (22 files)

These are historical records of fixes that are now complete and integrated:

```bash
ALL_AGENTS_UPDATED.md
AUTONOMOUS_AGENT_SUCCESS.md
CLEANUP_COMPLETE.md
CRITICAL_FIXES_SUMMARY.md
CURIOSITY_AGENDA_SUCCESS.md
DATABASE_CONFIG_FIX_SUMMARY.md
DAY_TRAINING_20MIN_UPDATE.md
DAY_TRAINING_FIXES.md
DOCKER_UPDATE_SUMMARY.md
FIX_SUMMARY.md
FIXES_APPLIED_DAY2.md
FIXES_APPLIED.md
LLM_INTEGRATION_SUMMARY.md
LLM_TESTING_SUCCESS.md
LLM_TIMEOUT_FIX.md
LLM_MODELS_OPTIMIZED.md
LLM_BENCHMARK_SYSTEM_READY.md
MONITORING_DASHBOARD_SUMMARY.md
OLLAMA_SETUP_COMPLETE.md
POSTGRES_FIX_SUMMARY.md
POSTGRES_FIX.md
REDIS_MESSAGE_BUG_FIX.md
TESTING_SUCCESS.md
```

### Category 2: Old Training Documentation (14 files)

Superseded by current training scripts and guides:

```bash
DAY_1_AGENT_ACTIONS.md
DAY_1_COMPANY_INTRO.md
DAY_1_READY.md
DAY_1_RESULTS.md
DAY_1_SIMULATION.md
DAY_TRAINING_GUIDE.md
DAY_TRAINING_TEST_RESULTS.md
DAY2_TESTING_GUIDE.md
DAY2_TRAINING_GUIDE.md
DAY2_WORKFLOW_DESIGN.md
HOW_DAY_1_WORKS.md
HOW_TO_RUN_CURIOSITY_AGENDA.md
HOW_TO_RUN_REAL_AGENT_COMMUNICATION.md
REAL_AGENT_COMMUNICATION.md
```

### Category 3: Old Testing Documentation (5 files)

```bash
TESTING_AGENT_SELF_SELECTION.md
TESTING_SUCCESS.md
TESTING_THE_DASHBOARD.md
REAL_AGENTS_QUICK_START.md
STARTING_AGENTS.md
```

### Category 4: Old Architecture Documents (6 files)

These are superseded by ECHO_ARCHITECTURE.md and current docs:

```bash
PHASE_3_ARCHITECTURE.md
PHASE_4_ARCHITECTURE.md
DISTRIBUTED_SYSTEMS_IMPROVEMENTS.md
WEEK_1_BUGS_FOUND.md
WHAT_AGENTS_DID.md
WHY_PING_ERRORS_ARE_NORMAL.md
```

### Category 5: Logs and Backup Files (4 files)

```bash
ollama_setup_fixed.log        # 7.4MB
ollama_setup.log              # 3.7KB
day_training.sh.bak           # Backup script
run_migrations.sql            # Should be in shared/priv/repo/migrations/
```

### Category 6: Root Test Scripts (2 files)

Should be in test/ directory:

```bash
test_llm_integration_simple.exs
test_remote_llm.exs
```

### Category 7: Deprecated Shell Scripts (13 files)

```bash
day2_training.sh              # Replaced by day2_training_v2.sh
monitor_conversation.sh       # Unused (460 bytes)
run_day1_all_agents.sh        # Replaced by run_day1_autonomous.sh
run_day1_autonomous.sh        # Use run_autonomous_agents.sh instead
send_agent_message.sh         # Replaced by send_agent_message_fixed.sh
start_ceo.sh                  # Functionality in start_ceo_cto.sh
start_cto.sh                  # Functionality in start_ceo_cto.sh
test_fix.sh                   # Temporary test script
test_senior_architect_llm.sh  # Use scripts/agents/test_agent_llm.sh instead
trigger_curiosity_autonomous.sh # Specific to old workflow
```

**Keep these testing scripts:**
- `test_agents.sh` ✅ (Still used)
- `test_agent_conversation.sh` ✅ (Still used)
- `test_self_selection.sh` ✅ (Still used)

### Category 8: Old Training Logs Directories (8 directories)

Inside `logs/` directory:

```bash
logs/day1_20251103_141751/
logs/day1_20251103_141850/
logs/day1_20251103_142258/
logs/day1_20251103_150000/
logs/day1_20251103_150507/
logs/day1_20251103_151242/
logs/day1_20251103_153301/
logs/day1_20251103_154010/
logs/day1_20251103_160332/
```

**Keep these log directories:**
- `logs/autonomous/` ✅
- `logs/curiosity_agenda/` ✅
- `logs/curiosity_session/` ✅
- `logs/day_training/` ✅

### Category 9: Duplicate Config Files (2 files)

```bash
claude_desktop_config_all_agents.json    # Specific config, may keep if needed
claude_desktop_config.template.json      # Template, may keep if needed
```

**Decision:** Review these - may be useful as templates

---

## ✅ Files to KEEP (Important Documentation)

These are current, referenced, and actively used:

```bash
# Core Documentation
CLAUDE.md                        ✅ New distributed root
CLAUDE.md.backup                 ✅ Backup of original
README.md                        ✅ Main readme
GETTING_STARTED.md              ✅ Setup guide
ECHO_ARCHITECTURE.md            ✅ Architecture reference
QUICK_REFERENCE.md              ✅ Quick commands

# Current Guides (referenced in README.md)
CLAUDE_DESKTOP_SETUP.md         ✅ Setup guide
DEMO_GUIDE.md                   ✅ Demo scenarios
AGENT_INTEGRATION_GUIDE.md      ✅ Integration guide
AUTONOMOUS_MODE_GUIDE.md        ✅ Autonomous mode
HOW_TO_TEST.md                  ✅ Testing guide
HOW_TO_RUN_REAL_AGENTS.md      ✅ Running agents guide

# Setup & Deployment
DOCKER_QUICKSTART.md            ✅ Docker setup
MAC_MINI_SETUP_GUIDE.md         ✅ Hardware setup
OLLAMA_GUIDE.md                 ✅ LLM setup

# Specific Guides
MONITORING_DASHBOARD_GUIDE.md   ✅ Dashboard guide
CEO_CTO_DISCUSSION_GUIDE.md     ✅ Conversation guide

# New Distributed Context Files
agents/claude.md                ✅ Agent patterns
shared/claude.md                ✅ Shared library
monitor/claude.md               ✅ Dashboard context
workflows/claude.md             ✅ Workflow patterns
training/claude.md              ✅ Training context
scripts/claude.md               ✅ Scripts context
docker/claude.md                ✅ Deployment context

# Structure Documentation
.claude/CONTEXT_STRUCTURE.md    ✅ Context documentation
DISTRIBUTED_CONTEXT_COMPLETE.md ✅ Implementation summary
```

---

## 📊 Summary

| Category | Files | Size Impact |
|----------|-------|-------------|
| Fix/Summary Docs | 22 | ~150KB |
| Training Docs | 14 | ~120KB |
| Testing Docs | 5 | ~50KB |
| Architecture Docs | 6 | ~80KB |
| Logs/Backups | 4 | ~7.5MB |
| Test Scripts | 2 | ~10KB |
| Deprecated Scripts | 13 | ~150KB |
| Old Log Directories | 8 | ~2MB |
| **TOTAL** | **74 items** | **~10MB** |

---

## 🚀 Cleanup Commands

### Safe Cleanup Script

```bash
#!/bin/bash
# cleanup_deprecated.sh - Remove deprecated files from echo repo

set -euo pipefail

echo "🗑️  Echo Repository Cleanup"
echo "============================="
echo ""
echo "This will delete 74 deprecated files (~10MB)"
read -p "Continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

# Create backup before deletion
BACKUP_DIR="./deprecated_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo ""
echo "📦 Creating backup in $BACKUP_DIR..."

# Backup files before deletion
cp *_FIX*.md *_SUMMARY*.md *_SUCCESS*.md *_COMPLETE*.md "$BACKUP_DIR/" 2>/dev/null || true
cp DAY*.md HOW*.md REAL*.md TESTING*.md STARTING*.md "$BACKUP_DIR/" 2>/dev/null || true
cp *.log *.bak *.exs "$BACKUP_DIR/" 2>/dev/null || true

echo "✅ Backup created"
echo ""
echo "🗑️  Deleting deprecated files..."

# Delete fix/summary documents
rm -f *_FIX*.md *_SUMMARY*.md *_SUCCESS*.md *_COMPLETE*.md *_FIXES*.md *_UPDATE*.md

# Delete old training docs
rm -f DAY_1_*.md DAY_TRAINING*.md DAY2_*.md HOW_DAY_1*.md
rm -f HOW_TO_RUN_CURIOSITY*.md HOW_TO_RUN_REAL*.md REAL_*.md

# Delete old testing docs
rm -f TESTING_*.md STARTING_AGENTS.md

# Delete old architecture docs
rm -f PHASE_*.md DISTRIBUTED_SYSTEMS_IMPROVEMENTS.md WEEK_1_BUGS_FOUND.md
rm -f WHAT_AGENTS_DID.md WHY_PING_ERRORS_ARE_NORMAL.md

# Delete logs and backups
rm -f *.log *.bak run_migrations.sql

# Delete test scripts from root
rm -f test_llm_integration_simple.exs test_remote_llm.exs

# Delete deprecated shell scripts
rm -f day2_training.sh monitor_conversation.sh
rm -f run_day1_all_agents.sh run_day1_autonomous.sh
rm -f send_agent_message.sh start_ceo.sh start_cto.sh
rm -f test_fix.sh test_senior_architect_llm.sh
rm -f trigger_curiosity_autonomous.sh

# Delete old log directories
rm -rf logs/day1_20251103_*

# Note: DISTRIBUTED_CONTEXT_COMPLETE.md - keep this one (it's new)
# Note: Keep CLAUDE_DESKTOP_GUIDE.md - still referenced
# Note: Keep ADD_ALL_AGENTS.md, AGENT_BUILD_TEST_RESULTS.md - may be useful

echo "✅ Cleanup complete!"
echo ""
echo "📊 Summary:"
echo "  - Deleted: ~74 files"
echo "  - Freed: ~10MB disk space"
echo "  - Backup: $BACKUP_DIR"
echo ""
echo "💡 If you need any deleted file, restore from: $BACKUP_DIR"
```

### Quick Cleanup (No Backup)

**⚠️ WARNING: No backup created!**

```bash
# Delete all deprecated files at once
rm -f *_FIX*.md *_SUMMARY*.md *_SUCCESS*.md *_COMPLETE*.md *_FIXES*.md *_UPDATE*.md
rm -f DAY_1_*.md DAY_TRAINING*.md DAY2_*.md HOW_DAY_1*.md
rm -f HOW_TO_RUN_CURIOSITY*.md HOW_TO_RUN_REAL*.md REAL_*.md
rm -f TESTING_*.md STARTING_AGENTS.md
rm -f PHASE_*.md DISTRIBUTED_SYSTEMS_IMPROVEMENTS.md WEEK_1_BUGS_FOUND.md
rm -f WHAT_AGENTS_DID.md WHY_PING_ERRORS_ARE_NORMAL.md
rm -f *.log *.bak run_migrations.sql
rm -f test_llm_integration_simple.exs test_remote_llm.exs
rm -f day2_training.sh monitor_conversation.sh run_day1_all_agents.sh run_day1_autonomous.sh
rm -f send_agent_message.sh start_ceo.sh start_cto.sh test_fix.sh
rm -f test_senior_architect_llm.sh trigger_curiosity_autonomous.sh
rm -rf logs/day1_20251103_*

echo "✅ Cleanup complete!"
```

---

## 🔍 Verification After Cleanup

```bash
# Check remaining documentation
ls -lh *.md | grep -v "CLAUDE\|README\|GETTING_STARTED\|ECHO_ARCHITECTURE\|QUICK_REFERENCE"

# Verify distributed context files exist
ls -l agents/claude.md shared/claude.md monitor/claude.md workflows/claude.md training/claude.md scripts/claude.md docker/claude.md

# Check repo size
du -sh .

# Verify git status
git status
```

---

## 📋 Post-Cleanup Checklist

- [ ] Backup created successfully
- [ ] All deprecated files deleted
- [ ] Distributed context files intact
- [ ] Active documentation files preserved
- [ ] Git status clean (no important files deleted)
- [ ] Scripts still work (./setup.sh, ./echo.sh)
- [ ] Monitor dashboard still accessible
- [ ] Agents still compile

---

**Ready to clean up? Use the safe cleanup script above!**
