#!/usr/bin/env bash
# Quick wrapper for LocalCode - simplified session management
# Usage: source this file, then use: lc_start, lc_query, lc_end

SESSIONS_DIR="${HOME}/.localcode/sessions"

# Start session and store in env variable
lc_start() {
    local project_path="${1:-.}"
    export LOCALCODE_SESSION=$(./scripts/llm/localcode_session.sh start "$project_path" 2>/dev/null | tail -1)
    echo "✓ Session started: $LOCALCODE_SESSION"
    echo "  Use: lc_query \"your question\""
}

# Query current session
lc_query() {
    if [[ -z "$LOCALCODE_SESSION" ]]; then
        echo "✗ No active session. Run: lc_start" >&2
        return 1
    fi

    # Set timeout via env var (default 180 seconds / 3 minutes for local LLMs)
    export LLM_TIMEOUT="${LLM_TIMEOUT:-180}"

    ./scripts/llm/localcode_query.sh "$LOCALCODE_SESSION" "$@"
}

# Interactive mode
lc_interactive() {
    if [[ -z "$LOCALCODE_SESSION" ]]; then
        echo "✗ No active session. Run: lc_start" >&2
        return 1
    fi

    ./scripts/llm/localcode_query.sh "$LOCALCODE_SESSION" --interactive
}

# End session
lc_end() {
    if [[ -z "$LOCALCODE_SESSION" ]]; then
        echo "✗ No active session" >&2
        return 1
    fi

    ./scripts/llm/localcode_session.sh end "$LOCALCODE_SESSION" 2>/dev/null
    echo "✓ Session ended: $LOCALCODE_SESSION"
    unset LOCALCODE_SESSION
}

# List sessions
lc_list() {
    ./scripts/llm/localcode_session.sh list
}

# Show current session
lc_show() {
    if [[ -z "$LOCALCODE_SESSION" ]]; then
        echo "✗ No active session" >&2
        return 1
    fi

    ./scripts/llm/localcode_session.sh show "$LOCALCODE_SESSION"
}

# Export functions
export -f lc_start
export -f lc_query
export -f lc_interactive
export -f lc_end
export -f lc_list
export -f lc_show

echo "LocalCode helper functions loaded:"
echo "  lc_start [path]       - Start new session"
echo "  lc_query \"question\"   - Query current session"
echo "  lc_interactive        - Interactive mode"
echo "  lc_end                - End current session"
echo "  lc_list               - List all sessions"
echo "  lc_show               - Show current session"
echo ""
echo "Environment variables:"
echo "  LLM_TIMEOUT=180       - Query timeout (default: 180 seconds / 3 minutes)"
echo "  LLM_MODEL             - Model to use (default: deepseek-coder:6.7b)"
