#!/usr/bin/env bash
# Context Builder for Local LLM Queries
# Builds optimized context for querying local Ollama models
# Architecture: Tiered context injection (Static Core + Dynamic Task + Conversation + Question)

set -euo pipefail

# Configuration
OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-http://localhost:11434}"
DEFAULT_MODEL="${LLM_MODEL:-deepseek-coder:6.7b}"
TIMEOUT="${LLM_TIMEOUT:-30000}"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Template types
TEMPLATE_CODE_REVIEW="code_review"
TEMPLATE_FEATURE_DESIGN="feature_design"
TEMPLATE_DEBUGGING="debugging"
TEMPLATE_ARCHITECTURE="architecture"
TEMPLATE_GENERAL="general"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}$1${NC}" >&2
}

success() {
    echo -e "${GREEN}$1${NC}" >&2
}

# Get current git context
get_git_context() {
    cd "$PROJECT_ROOT" || error "Cannot access project root"

    local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local last_commit=$(git log -1 --oneline 2>/dev/null || echo "No commits")

    echo "Branch: $branch | Last: $last_commit"
}

# Get ECHO phase from CLAUDE.md
get_project_phase() {
    if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
        grep -A 1 "Current Phase" "$PROJECT_ROOT/CLAUDE.md" | tail -1 | sed 's/\*\*//g' | xargs || echo "Unknown"
    else
        echo "Unknown"
    fi
}

# Build TIER 1: Static Core (~500 tokens)
build_tier1_static_core() {
    local phase=$(get_project_phase)
    local git_ctx=$(get_git_context)

    cat <<EOF
# TIER 1: Static Core
Project: ECHO (Executive Coordination & Hierarchical Organization)
Type: Multi-agent AI organizational model (9 autonomous agents)
Tech Stack: Elixir/OTP 27, PostgreSQL 16, Redis 7, MCP Protocol, Ollama LLMs
Architecture: 9 MCP servers → PostgreSQL (state) + Redis (message bus) + Ollama (inference)

Current Phase: $phase
Git Context: $git_ctx

Agents: CEO (qwen2.5:14b), CTO (deepseek-coder:33b), CHRO (llama3.1:8b),
        Operations (mistral:7b), PM (llama3.1:8b), Architect (deepseek-coder:33b),
        UI/UX (llama3.2-vision:11b), Developer (deepseek-coder:6.7b), Test (codellama:13b)

Critical Rules:
1. Never break existing tests (mix test must pass)
2. All agent communication via Redis pub/sub + PostgreSQL
3. Compile shared library first (cd shared && mix compile)
4. Never drop database without permission
5. Keep implementations simple - don't overengineer

Decision Modes: Autonomous, Collaborative, Hierarchical, Human-in-the-Loop
EOF
}

# Build TIER 2: Dynamic Task Context (~1500 tokens)
# Parameters: context_type, relevant_files, code_snippets, etc.
build_tier2_dynamic_context() {
    local context_type="$1"
    shift

    case "$context_type" in
        "code_review")
            build_tier2_code_review "$@"
            ;;
        "feature_design")
            build_tier2_feature_design "$@"
            ;;
        "debugging")
            build_tier2_debugging "$@"
            ;;
        "architecture")
            build_tier2_architecture "$@"
            ;;
        *)
            build_tier2_general "$@"
            ;;
    esac
}

build_tier2_code_review() {
    local file_path="${1:-}"
    local line_range="${2:-}"
    local code_snippet="${3:-}"

    cat <<EOF
# TIER 2: Code Review Context
File: $file_path${line_range:+:$line_range}
${code_snippet:+Code:
\`\`\`
$code_snippet
\`\`\`}

Database Schema: decisions (mode, status, consensus), messages (from_role, to_role, thread_id),
                 memories (key, value, tags), decision_votes, agent_status
Redis Channels: messages:{role}, messages:all, messages:leadership, decisions:*
EOF
}

build_tier2_feature_design() {
    local feature_name="${1:-}"
    local relevant_modules="${2:-}"

    cat <<EOF
# TIER 2: Feature Design Context
Feature: $feature_name
${relevant_modules:+Related Modules: $relevant_modules}

Database Schema: decisions, messages, memories, decision_votes, agent_status
Workflow Engine: EchoShared.WorkflowEngine
Message Bus: EchoShared.MessageBus (Redis pub/sub + PostgreSQL persistence)
MCP Server: EchoShared.MCP.Server behavior (JSON-RPC 2.0 over stdio)
EOF
}

build_tier2_debugging() {
    local error_message="${1:-}"
    local stack_trace="${2:-}"
    local recent_changes="${3:-}"

    cat <<EOF
# TIER 2: Debugging Context
${error_message:+Error: $error_message}
${stack_trace:+Stack Trace:
\`\`\`
$stack_trace
\`\`\`}
${recent_changes:+Recent Changes: $recent_changes}

Infrastructure: PostgreSQL (port 5433), Redis (port 6383), Ollama (port 11434)
Common Issues: Shared library not compiled, DB/Redis not running, MCP stdio exit on close
EOF
}

build_tier2_architecture() {
    local component="${1:-}"
    local context="${2:-}"

    cat <<EOF
# TIER 2: Architecture Context
Component: $component
${context:+Context: $context}

Current Architecture:
- Each agent is independent MCP server (stdio mode)
- Agents communicate via Redis pub/sub channels
- All messages persist to PostgreSQL for audit trail
- Each agent has specialized Ollama model for reasoning
- Phoenix LiveView dashboard for monitoring

Design Patterns:
- GenServer for agent processes
- Ecto for database (PostgreSQL)
- Redix for Redis pub/sub
- Jason for JSON encoding/decoding
EOF
}

build_tier2_general() {
    local context="${1:-}"

    cat <<EOF
# TIER 2: Task Context
${context:+$context}

Key Directories:
- agents/{role}/ - Individual agent implementations
- shared/ - Shared Elixir library (EchoShared.*)
- workflows/ - Multi-agent workflow patterns
- monitor/ - Phoenix LiveView dashboard
EOF
}

# Build TIER 3: Conversation State (~300 tokens)
build_tier3_conversation() {
    local user_goal="${1:-Analyze and improve ECHO}"
    local recent_context="${2:-}"
    local decisions_made="${3:-}"

    cat <<EOF

# TIER 3: Conversation State
User Goal: $user_goal
${recent_context:+Recent Context: $recent_context}
${decisions_made:+Decisions Made: $decisions_made}
EOF
}

# Build TIER 4: Specific Question (~200 tokens)
build_tier4_question() {
    local question="$1"

    cat <<EOF

# TIER 4: Specific Question
$question

Provide a technical, specific answer based on the context above.
EOF
}

# Query Ollama with built context
query_ollama() {
    local prompt="$1"
    local model="${2:-$DEFAULT_MODEL}"
    local timeout="${3:-$TIMEOUT}"

    info "Querying $model (timeout: ${timeout}ms)..."

    # Escape prompt for JSON (using jq for safety)
    local response=$(curl -s -m $((timeout / 1000)) "$OLLAMA_ENDPOINT/api/generate" \
        -d "$(jq -n --arg model "$model" --arg prompt "$prompt" '{
            model: $model,
            prompt: $prompt,
            stream: false
        }')" | jq -r '.response' 2>/dev/null)

    if [[ -z "$response" ]]; then
        error "Failed to get response from Ollama"
    fi

    echo "$response"
}

# Main query function with template support
query_with_template() {
    local template_type="$1"
    shift

    # Extract parameters
    local question=""
    local user_goal=""
    local tier2_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --question)
                question="$2"
                shift 2
                ;;
            --goal)
                user_goal="$2"
                shift 2
                ;;
            --model)
                local model="$2"
                shift 2
                ;;
            *)
                tier2_args+=("$1")
                shift
                ;;
        esac
    done

    [[ -z "$question" ]] && error "Question is required (--question)"

    # Build complete context
    local tier1=$(build_tier1_static_core)
    local tier2=$(build_tier2_dynamic_context "$template_type" "${tier2_args[@]}")
    local tier3=$(build_tier3_conversation "$user_goal")
    local tier4=$(build_tier4_question "$question")

    local full_prompt="$tier1

$tier2
$tier3
$tier4"

    # Query
    query_ollama "$full_prompt" "${model:-$DEFAULT_MODEL}"
}

# Usage help
usage() {
    cat <<EOF
Usage: $0 <template_type> [options]

Template Types:
  code_review       - Review code for bugs/performance/security
  feature_design    - Design new feature implementation
  debugging         - Debug errors and issues
  architecture      - Architectural design questions
  general           - General technical questions

Options:
  --question TEXT   - The specific question (required)
  --goal TEXT       - User's overall goal (optional)
  --model MODEL     - Ollama model to use (default: $DEFAULT_MODEL)

Examples:
  # Code review
  $0 code_review --question "Review this for security issues" \\
     "shared/lib/message_bus.ex" "1-50" "\$(cat shared/lib/message_bus.ex)"

  # Feature design
  $0 feature_design --question "How to implement feature X?" \\
     "Feature X" "EchoShared.MessageBus, EchoShared.WorkflowEngine"

  # Debugging
  $0 debugging --question "Why is this failing?" \\
     "Connection refused" "\$(cat error.log)" "Added Redis auth"

  # Architecture
  $0 architecture --question "Should we use GenServer or Agent?" \\
     "State management" "Need concurrent access to shared state"

  # General
  $0 general --question "What's the best approach?" \\
     "Need to implement workflow orchestration"
EOF
    exit 1
}

# Main entry point
main() {
    if [[ $# -lt 1 ]]; then
        usage
    fi

    query_with_template "$@"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
