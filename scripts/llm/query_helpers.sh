#!/usr/bin/env bash
# Simple helper functions for querying local LLM with optimal context
# Source this file to use these functions

# Configuration (don't use set -euo pipefail when sourcing)
# Find script directory - handle both direct execution and sourcing
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Fallback: assume called from project root or find it
    if [[ -f "scripts/llm/context_builder.sh" ]]; then
        SCRIPT_DIR="$(pwd)/scripts/llm"
    else
        SCRIPT_DIR="/Users/pranav/Documents/echo/scripts/llm"
    fi
fi

CONTEXT_BUILDER="$SCRIPT_DIR/context_builder.sh"
OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-http://localhost:11434}"
LLM_MODEL="${LLM_MODEL:-deepseek-coder:6.7b}"

# Simple query function - just takes a question and context
# Returns LLM response
llm_query() {
    local question="$1"
    local context="${2:-}"
    local goal="${3:-Analyze and improve ECHO}"

    if [[ ! -f "$CONTEXT_BUILDER" ]]; then
        echo "Error: Context builder not found at $CONTEXT_BUILDER" >&2
        return 1
    fi

    bash "$CONTEXT_BUILDER" general \
        --question "$question" \
        --goal "$goal" \
        ${context:+"$context"}
}

# Code review helper
llm_code_review() {
    local file_path="$1"
    local question="$2"
    local code_snippet="${3:-}"

    bash "$CONTEXT_BUILDER" code_review \
        --question "$question" \
        "$file_path" "" "$code_snippet"
}

# Feature design helper
llm_feature_design() {
    local feature_name="$1"
    local question="$2"
    local related_modules="${3:-}"

    bash "$CONTEXT_BUILDER" feature_design \
        --question "$question" \
        "$feature_name" "$related_modules"
}

# Debugging helper
llm_debug() {
    local error_message="$1"
    local question="$2"
    local stack_trace="${3:-}"

    bash "$CONTEXT_BUILDER" debugging \
        --question "$question" \
        "$error_message" "$stack_trace"
}

# Architecture helper
llm_architecture() {
    local component="$1"
    local question="$2"
    local context="${3:-}"

    bash "$CONTEXT_BUILDER" architecture \
        --question "$question" \
        "$component" "$context"
}

# Quick query - minimal context for simple questions
llm_quick() {
    local question="$1"

    curl -s http://localhost:11434/api/generate -d "{
        \"model\": \"$LLM_MODEL\",
        \"prompt\": \"$question\",
        \"stream\": false
    }" | jq -r '.response'
}

# Export functions
export -f llm_query
export -f llm_code_review
export -f llm_feature_design
export -f llm_debug
export -f llm_architecture
export -f llm_quick
