#!/usr/bin/env bash
# Query Decision Logic
# Determines whether to query local LLM or skip based on task type
# Returns: 0 (should query), 1 (should skip)

set -euo pipefail

# Query patterns - these benefit from LLM consultation
QUERY_PATTERNS=(
    # Architecture & Design
    "architecture"
    "design"
    "implement"
    "approach"
    "pattern"
    "structure"
    "organize"

    # Code Analysis
    "review"
    "analyze"
    "security"
    "performance"
    "optimize"
    "refactor"
    "improve"

    # Problem Solving
    "debug"
    "error"
    "fix"
    "issue"
    "problem"
    "fail"
    "wrong"

    # Decision Making
    "should"
    "choose"
    "compare"
    "better"
    "vs"
    "alternative"
    "trade-off"

    # Understanding
    "explain"
    "understand"
    "how does"
    "why"
    "what could"
    "what if"
)

# Skip patterns - these don't need LLM
SKIP_PATTERNS=(
    # File operations
    "list files"
    "show files"
    "find file"
    "ls "
    "tree"

    # Reading
    "read file"
    "cat "
    "show content"
    "display"

    # Commands
    "run "
    "execute"
    "start"
    "stop"
    "restart"

    # Git operations
    "git status"
    "git log"
    "git diff"
    "git commit"
    "git push"

    # Simple queries
    "what is the path"
    "where is"
    "check if running"
    "is running"

    # Status checks
    "status"
    "health"
    "ping"
)

# Check if query matches skip patterns
should_skip() {
    local query="$1"
    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    for pattern in "${SKIP_PATTERNS[@]}"; do
        if echo "$query_lower" | grep -q "$pattern"; then
            return 0  # Should skip
        fi
    done

    return 1  # Should not skip
}

# Check if query matches query patterns
should_query() {
    local query="$1"
    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    # First check if we should skip
    if should_skip "$query"; then
        return 1  # Don't query
    fi

    # Check for query patterns
    for pattern in "${QUERY_PATTERNS[@]}"; do
        if echo "$query_lower" | grep -q "$pattern"; then
            return 0  # Should query
        fi
    done

    # Default: for ambiguous cases, query
    # Better to over-query than miss insights
    return 0
}

# Get recommendation with reasoning
get_recommendation() {
    local query="$1"

    if should_skip "$query"; then
        echo "SKIP"
        echo "Reason: This is a tool operation that doesn't benefit from LLM analysis"
        return 1
    elif should_query "$query"; then
        echo "QUERY"
        echo "Reason: This task benefits from LLM reasoning and analysis"
        return 0
    else
        echo "QUERY"
        echo "Reason: Ambiguous case - defaulting to query for safety"
        return 0
    fi
}

# Usage
usage() {
    cat <<EOF
Usage: $0 [options] "user query"

Options:
  --verbose, -v    Show reasoning
  --help, -h       Show this help

Returns:
  0 - Should query LLM
  1 - Should skip LLM (use tools directly)

Examples:
  # Check if should query
  $0 "How should I implement feature X?"
  echo \$?  # 0 (should query)

  # Check with reasoning
  $0 -v "List all files in src/"
  # Output: SKIP
  # Reason: This is a tool operation

  # In scripts
  if $0 "Debug this error"; then
      echo "Querying LLM..."
  else
      echo "Using direct tools..."
  fi
EOF
    exit 0
}

# Main
main() {
    local verbose=false
    local query=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                query="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$query" ]]; then
        echo "Error: Query is required" >&2
        usage
    fi

    if $verbose; then
        get_recommendation "$query"
    else
        if should_query "$query"; then
            exit 0
        else
            exit 1
        fi
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
