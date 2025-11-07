#!/usr/bin/env bash
# Session end hook for ECHO
# This script runs when a Claude Code session ends

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

# Read session data from stdin (with 10MB size limit to prevent memory exhaustion)
SESSION_DATA=$(head -c 10485760)
if [ ${#SESSION_DATA} -ge 10485760 ]; then
  echo "Warning: Session data truncated (exceeded 10MB)" >&2
fi

# Generate timestamp (BSD/macOS compatible)
if date --version &>/dev/null 2>&1; then
  # GNU date
  SESSION_END=$(date -u +"%Y-%m-%dT%H:%M:%S.%6NZ")
  FILENAME_TS=$(date -u +"%Y%m%d-%H%M%S")
else
  # BSD date (macOS)
  SESSION_END=$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")
  FILENAME_TS=$(date -u +"%Y%m%d-%H%M%S")
fi

# Create logs directory
LOG_DIR="$PROJECT_ROOT/logs/sessions"
mkdir -p "$LOG_DIR" || {
  echo "Error: Cannot create log directory: $LOG_DIR" >&2
  exit 1
}

# Clean up old session logs (keep only last 30 days)
find "$LOG_DIR" -name "session-*.json" -mtime +30 -delete 2>/dev/null || true

# Save session log
LOG_FILE="$LOG_DIR/session-${FILENAME_TS}.json"

# Safely escape session data to JSON (prevents command injection)
SESSION_DATA_JSON=$(printf '%s' "$SESSION_DATA" | jq -Rs '.' 2>/dev/null || printf '"%s"' "$SESSION_DATA")

# Create JSON log file - use temp file for atomic write
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" <<OUTER_EOF
{
  "ended_at": "$SESSION_END",
  "project": "ECHO",
  "session_data": $SESSION_DATA_JSON
}
OUTER_EOF

# Atomic move
mv "$TEMP_FILE" "$LOG_FILE"

# Log to system logger if available
if command -v logger &> /dev/null; then
  echo "Session ended at $SESSION_END" | logger -t echo-session-end
fi

# Silent success (Claude Code expects no output)
exit 0
