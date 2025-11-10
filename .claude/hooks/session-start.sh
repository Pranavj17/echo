#!/usr/bin/env bash
# Session start hook for ECHO
# This script runs when a Claude Code session starts and provides system status

set -euo pipefail

# Determine project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT" || {
  echo "Failed to change to project directory: $PROJECT_ROOT" >&2
  exit 1
}

# Verify we're in the right place
if [[ ! -f "CLAUDE.md" ]]; then
  echo "Error: Not in ECHO project directory (CLAUDE.md not found)" >&2
  exit 1
fi

# Check PostgreSQL status (Docker container on port 5433)
PG_STATUS="❌ Down"
if PGPASSWORD=postgres psql -U echo_org -h 127.0.0.1 -p 5433 -d echo_org -c "SELECT 1" &>/dev/null; then
  PG_STATUS="✅ Connected"

  # IMPORTANT: These queries contain NO user input - all values are hardcoded
  # Never interpolate variables into SQL queries to prevent SQL injection

  # Get decision stats (with COALESCE to handle NULL from SUM)
  DECISION_STATS=$(PGPASSWORD=postgres psql -U echo_org -h 127.0.0.1 -p 5433 -d echo_org -t -c \
    "SELECT COUNT(*) || ' total, ' || COALESCE(SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END), 0) || ' pending' FROM decisions;" 2>/dev/null || echo "N/A")

  # Get message stats (last 24h)
  MESSAGE_STATS=$(PGPASSWORD=postgres psql -U echo_org -h 127.0.0.1 -p 5433 -d echo_org -t -c \
    "SELECT COUNT(*) || ' total, ' || COUNT(DISTINCT from_role) || ' active agents' FROM messages WHERE created_at > NOW() - INTERVAL '24 hours';" 2>/dev/null || echo "N/A")
else
  DECISION_STATS="Database unavailable"
  MESSAGE_STATS="Database unavailable"
fi

# Check Redis status (Docker container on port 6383)
REDIS_STATUS="❌ Down"
if redis-cli -h 127.0.0.1 -p 6383 ping &>/dev/null; then
  REDIS_STATUS="✅ Connected"
fi

# Check Ollama models
OLLAMA_COUNT="0"
DEEPSEEK_STATUS="❌ Not available"
if command -v ollama &> /dev/null; then
  OLLAMA_COUNT=$(ollama list 2>/dev/null | grep -E "qwen|deepseek|llama|mistral|codellama" | wc -l | tr -d ' ')

  # Check if deepseek-coder:6.7b is available for dual-perspective workflow
  if ollama list 2>/dev/null | grep -q "deepseek-coder:6.7b"; then
    # Test if Ollama API is responsive
    if curl -s -m 5 http://localhost:11434/api/tags &>/dev/null; then
      DEEPSEEK_STATUS="✅ Active (dual-perspective mode enabled)"
    else
      DEEPSEEK_STATUS="⚠️  Model installed but API not responding"
    fi
  else
    DEEPSEEK_STATUS="❌ Model not installed"
  fi
fi

# Build boot info
BOOT_INFO=$(cat <<EOF
🏢 ECHO Organization Status
─────────────────────────────
📊 Infrastructure:
  PostgreSQL: ${PG_STATUS}
  Redis: ${REDIS_STATUS}

📦 Agents: 9 (CEO, CTO, CHRO, Ops, PM, Architect, UI/UX, Dev, Test)

🤖 LLM Models: ${OLLAMA_COUNT} installed
  Local LLM (deepseek-coder:6.7b): ${DEEPSEEK_STATUS}

📝 Last 24h Activity:
  Decisions: ${DECISION_STATS}
  Messages: ${MESSAGE_STATS}

💡 Dual-Perspective Mode: See CLAUDE.md Rule 8
   All responses include both Local LLM + Claude analysis
EOF
)

# Return JSON output with additionalContext using jq for safe JSON encoding
if command -v jq &> /dev/null; then
  # Use jq for proper JSON encoding
  jq -n --arg info "$BOOT_INFO" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $info
    }
  }'
else
  # Fallback: Manually escape for JSON
  ESCAPED_INFO=$(printf '%s' "$BOOT_INFO" | \
    sed 's/\\/\\\\/g' | \
    sed 's/"/\\"/g' | \
    awk '{printf "%s\\n", $0}' | \
    sed '$s/\\n$//')

  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${ESCAPED_INFO}"
  }
}
EOF
fi
