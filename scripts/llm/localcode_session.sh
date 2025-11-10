#!/usr/bin/env bash
# LocalCode Session Manager
# Replicates Claude Code startup flow for local LLM
# Usage: ./localcode_session.sh start <project_path>

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_DIR="${HOME}/.localcode/sessions"
OLLAMA_MODEL="${LLM_MODEL:-deepseek-coder:6.7b}"
OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-http://localhost:11434}"

# Ensure sessions directory exists
mkdir -p "$SESSIONS_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Helper functions
info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Generate session ID
generate_session_id() {
    echo "session_$(date +%Y%m%d_%H%M%S)_$$"
}

# Build startup context from project path
build_startup_context() {
    local project_path="$1"
    local session_dir="$2"

    info "Building startup context for: $project_path"

    cd "$project_path" || {
        error "Cannot access project directory: $project_path"
        return 1
    }

    local context_file="$session_dir/startup_context.txt"

    cat > "$context_file" <<'CONTEXT_START'
# LOCALCODE SESSION STARTUP CONTEXT
# This context is injected at the beginning of every query

## PROJECT OVERVIEW

CONTEXT_START

    # 1. Read CLAUDE.md if exists
    if [[ -f "CLAUDE.md" ]]; then
        echo "### Project Rules (from CLAUDE.md)" >> "$context_file"
        echo '```' >> "$context_file"
        head -200 CLAUDE.md >> "$context_file"
        echo '```' >> "$context_file"
        echo "" >> "$context_file"
        success "Loaded CLAUDE.md (200 lines)"
    fi

    # 2. Run session-start hook if exists
    if [[ -f ".claude/hooks/session-start.sh" ]]; then
        echo "### System Status (from session-start.sh)" >> "$context_file"
        echo '```json' >> "$context_file"
        bash .claude/hooks/session-start.sh 2>/dev/null || echo '{"status": "hook_failed"}' >> "$context_file"
        echo '```' >> "$context_file"
        echo "" >> "$context_file"
        success "Executed session-start hook"
    fi

    # 3. Git context
    if [[ -d ".git" ]]; then
        echo "### Git Context" >> "$context_file"
        echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')" >> "$context_file"
        echo "Last Commit: $(git log -1 --oneline 2>/dev/null || echo 'No commits')" >> "$context_file"
        echo "Status: $(git status --short | wc -l) changed files" >> "$context_file"
        echo "" >> "$context_file"
        success "Loaded git context"
    fi

    # 4. Directory structure (top-level only)
    echo "### Directory Structure" >> "$context_file"
    echo '```' >> "$context_file"
    ls -1 | head -20 >> "$context_file"
    echo '```' >> "$context_file"
    echo "" >> "$context_file"
    success "Loaded directory structure"

    # 5. Key file detection
    echo "### Key Files Detected" >> "$context_file"
    for pattern in "mix.exs" "package.json" "requirements.txt" "Cargo.toml" "go.mod" "Makefile" "docker-compose.yml"; do
        if [[ -f "$pattern" ]]; then
            echo "- $pattern" >> "$context_file"
        fi
    done
    echo "" >> "$context_file"

    success "Startup context built: $context_file"
    echo "$context_file"
}

# Initialize session
start_session() {
    local project_path="${1:-$(pwd)}"

    # Resolve absolute path
    project_path="$(cd "$project_path" && pwd)"

    local session_id=$(generate_session_id)
    local session_dir="$SESSIONS_DIR/$session_id"

    mkdir -p "$session_dir"

    info "Starting LocalCode session: $session_id"
    info "Project: $project_path"

    # Build startup context
    local context_file=$(build_startup_context "$project_path" "$session_dir")

    # Create session metadata
    cat > "$session_dir/session.json" <<EOF
{
  "session_id": "$session_id",
  "project_path": "$project_path",
  "model": "$OLLAMA_MODEL",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "conversation_turn": 0
}
EOF

    # Create empty conversation history
    echo "[]" > "$session_dir/conversation.json"

    # Create tool results log
    echo "[]" > "$session_dir/tool_results.json"

    success "Session started: $session_id"
    echo "" >&2
    echo -e "${CYAN}Session Directory:${NC} $session_dir" >&2
    echo -e "${CYAN}To query:${NC} $SCRIPT_DIR/localcode_query.sh $session_id \"your question\"" >&2
    echo "" >&2
    # Only session ID goes to stdout (for variable capture)
    echo "$session_id"
}

# List active sessions
list_sessions() {
    info "Active LocalCode sessions:"
    echo ""

    if [[ ! -d "$SESSIONS_DIR" ]] || [[ -z "$(ls -A "$SESSIONS_DIR" 2>/dev/null)" ]]; then
        warn "No active sessions found"
        return 0
    fi

    for session_dir in "$SESSIONS_DIR"/session_*; do
        if [[ -f "$session_dir/session.json" ]]; then
            local session_id=$(basename "$session_dir")
            local project_path=$(jq -r '.project_path' "$session_dir/session.json")
            local started_at=$(jq -r '.started_at' "$session_dir/session.json")
            local turn=$(jq -r '.conversation_turn' "$session_dir/session.json")

            echo -e "${GREEN}$session_id${NC}"
            echo "  Project: $project_path"
            echo "  Started: $started_at"
            echo "  Turns: $turn"
            echo ""
        fi
    done
}

# End session
end_session() {
    local session_id="$1"
    local session_dir="$SESSIONS_DIR/$session_id"

    if [[ ! -d "$session_dir" ]]; then
        error "Session not found: $session_id"
        return 1
    fi

    info "Ending session: $session_id"

    # Archive session
    local archive_dir="$SESSIONS_DIR/archive"
    mkdir -p "$archive_dir"

    tar -czf "$archive_dir/${session_id}.tar.gz" -C "$SESSIONS_DIR" "$session_id" 2>/dev/null
    rm -rf "$session_dir"

    success "Session archived to: $archive_dir/${session_id}.tar.gz"
}

# Show session info
show_session() {
    local session_id="$1"
    local session_dir="$SESSIONS_DIR/$session_id"

    if [[ ! -d "$session_dir" ]]; then
        error "Session not found: $session_id"
        return 1
    fi

    echo -e "${CYAN}Session: $session_id${NC}"
    echo ""
    cat "$session_dir/session.json" | jq '.'
    echo ""

    local turn_count=$(jq '. | length' "$session_dir/conversation.json")
    echo -e "${CYAN}Conversation History:${NC} $turn_count turns"

    if [[ $turn_count -gt 0 ]]; then
        echo ""
        jq -r '.[] | "[\(.role)] \(.content | .[0:100])..."' "$session_dir/conversation.json"
    fi
}

# Main CLI
main() {
    local command="${1:-help}"

    case "$command" in
        start)
            shift
            start_session "$@"
            ;;
        list)
            list_sessions
            ;;
        end)
            shift
            end_session "$@"
            ;;
        show)
            shift
            show_session "$@"
            ;;
        help|--help|-h)
            cat <<EOF
LocalCode Session Manager - Replicate Claude Code flow for local LLM

Usage:
  $0 start [project_path]     Start new session (default: current directory)
  $0 list                     List active sessions
  $0 show <session_id>        Show session details
  $0 end <session_id>         End and archive session
  $0 help                     Show this help

Examples:
  # Start session in current directory
  $0 start

  # Start session in specific project
  $0 start /path/to/project

  # List all sessions
  $0 list

  # Show session details
  $0 show session_20250111_123456_12345

  # End session
  $0 end session_20250111_123456_12345

Session files stored in: $SESSIONS_DIR
EOF
            ;;
        *)
            error "Unknown command: $command"
            echo "Run '$0 help' for usage"
            return 1
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
