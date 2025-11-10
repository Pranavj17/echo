#!/usr/bin/env bash
# LocalCode Query Interface
# Sends queries to local LLM with full session context
# Usage: ./localcode_query.sh <session_id> "your question"

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_DIR="${HOME}/.localcode/sessions"
OLLAMA_MODEL="${LLM_MODEL:-deepseek-coder:6.7b}"
OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-http://localhost:11434}"
OLLAMA_TIMEOUT="${LLM_TIMEOUT:-180}"  # Default 3 minutes (180s) for local LLMs with large context
CONTEXT_BUILDER="$SCRIPT_DIR/context_builder.sh"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $1" >&2; }
success() { echo -e "${GREEN}✓${NC} $1" >&2; }
error() { echo -e "${RED}✗${NC} $1" >&2; }
warn() { echo -e "${YELLOW}⚠${NC} $1" >&2; }

# Build complete query context
build_query_context() {
    local session_dir="$1"
    local question="$2"

    local context_parts=()

    # Part 1: Startup context (static, from session initialization)
    if [[ -f "$session_dir/startup_context.txt" ]]; then
        context_parts+=("$(cat "$session_dir/startup_context.txt")")
    fi

    # Part 2: Conversation history (last 5 turns for context)
    local conv_history=$(jq -r '
        .[-5:] |
        map("[\(.role | ascii_upcase)] \(.content)") |
        join("\n\n")
    ' "$session_dir/conversation.json" 2>/dev/null || echo "")

    if [[ -n "$conv_history" ]]; then
        context_parts+=("## CONVERSATION HISTORY (Last 5 turns)")
        context_parts+=("$conv_history")
        context_parts+=("")
    fi

    # Part 3: Recent tool results (last 3)
    local tool_results=$(jq -r '
        .[-3:] |
        map("[TOOL: \(.tool)] \(.result | .[0:500])") |
        join("\n\n")
    ' "$session_dir/tool_results.json" 2>/dev/null || echo "")

    if [[ -n "$tool_results" ]]; then
        context_parts+=("## RECENT TOOL EXECUTIONS")
        context_parts+=("$tool_results")
        context_parts+=("")
    fi

    # Part 4: Current question
    context_parts+=("## CURRENT QUESTION")
    context_parts+=("$question")
    context_parts+=("")
    context_parts+=("Provide a clear, technical answer. If you need to see file contents or run commands, say: 'TOOL_REQUEST: read_file(path)' or 'TOOL_REQUEST: grep_code(pattern)' or 'TOOL_REQUEST: run_bash(command)'")

    # Combine all parts
    printf "%s\n" "${context_parts[@]}"
}

# Query Ollama with context
query_llm() {
    local full_context="$1"
    local model="$2"

    info "Querying $model (timeout: ${OLLAMA_TIMEOUT}s)..."

    # Use configurable timeout
    local response=$(curl -s -m "$OLLAMA_TIMEOUT" "$OLLAMA_ENDPOINT/api/generate" \
        -d "$(jq -n --arg model "$model" --arg prompt "$full_context" '{
            model: $model,
            prompt: $prompt,
            stream: false,
            options: {
                temperature: 0.7,
                num_ctx: 8192
            }
        }')" 2>&1)

    # Check for curl errors
    if [[ $? -ne 0 ]]; then
        error "Curl failed: $response"
        return 1
    fi

    # Extract response from JSON
    response=$(echo "$response" | jq -r '.response' 2>/dev/null)

    if [[ -z "$response" ]]; then
        error "Failed to get response from Ollama"
        return 1
    fi

    echo "$response"
}

# Parse tool requests from LLM response
parse_tool_requests() {
    local response="$1"

    # Extract TOOL_REQUEST: patterns
    echo "$response" | grep -o 'TOOL_REQUEST: [^)]*)'
}

# Execute tool
execute_tool() {
    local tool_call="$1"
    local session_dir="$2"

    local project_path=$(jq -r '.project_path' "$session_dir/session.json")

    info "Executing tool: $tool_call"

    local result=""

    case "$tool_call" in
        read_file*)
            local file_path=$(echo "$tool_call" | grep -oP 'read_file\(\K[^\)]+' | tr -d '"' | tr -d "'")
            if [[ -f "$project_path/$file_path" ]]; then
                result=$(head -100 "$project_path/$file_path")
                success "Read file: $file_path (first 100 lines)"
            else
                result="ERROR: File not found: $file_path"
                error "$result"
            fi
            ;;

        grep_code*)
            local pattern=$(echo "$tool_call" | grep -oP 'grep_code\(\K[^\)]+' | tr -d '"' | tr -d "'")
            result=$(cd "$project_path" && grep -r "$pattern" . 2>/dev/null | head -20)
            success "Searched for: $pattern"
            ;;

        glob_files*)
            local glob_pattern=$(echo "$tool_call" | grep -oP 'glob_files\(\K[^\)]+' | tr -d '"' | tr -d "'")
            result=$(cd "$project_path" && find . -name "$glob_pattern" 2>/dev/null | head -20)
            success "Found files matching: $glob_pattern"
            ;;

        run_bash*)
            local command=$(echo "$tool_call" | grep -oP 'run_bash\(\K[^\)]+' | tr -d '"' | tr -d "'")
            result=$(cd "$project_path" && bash -c "$command" 2>&1 | head -50)
            success "Executed: $command"
            ;;

        *)
            result="ERROR: Unknown tool: $tool_call"
            error "$result"
            ;;
    esac

    # Store tool result
    local tool_entry=$(jq -n \
        --arg tool "$tool_call" \
        --arg result "$result" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{tool: $tool, result: $result, timestamp: $timestamp}')

    jq ". += [$tool_entry]" "$session_dir/tool_results.json" > "$session_dir/tool_results.json.tmp"
    mv "$session_dir/tool_results.json.tmp" "$session_dir/tool_results.json"

    echo "$result"
}

# Save conversation turn
save_turn() {
    local session_dir="$1"
    local question="$2"
    local response="$3"

    # Add question
    local user_entry=$(jq -n --arg content "$question" '{role: "user", content: $content}')
    jq ". += [$user_entry]" "$session_dir/conversation.json" > "$session_dir/conversation.json.tmp"
    mv "$session_dir/conversation.json.tmp" "$session_dir/conversation.json"

    # Add response
    local assistant_entry=$(jq -n --arg content "$response" '{role: "assistant", content: $content}')
    jq ". += [$assistant_entry]" "$session_dir/conversation.json" > "$session_dir/conversation.json.tmp"
    mv "$session_dir/conversation.json.tmp" "$session_dir/conversation.json"

    # Increment turn counter
    local turn=$(jq -r '.conversation_turn' "$session_dir/session.json")
    jq ".conversation_turn = $((turn + 1))" "$session_dir/session.json" > "$session_dir/session.json.tmp"
    mv "$session_dir/session.json.tmp" "$session_dir/session.json"
}

# Main query function
query() {
    local session_id="$1"
    local question="$2"
    local session_dir="$SESSIONS_DIR/$session_id"

    if [[ ! -d "$session_dir" ]]; then
        error "Session not found: $session_id"
        return 1
    fi

    local model=$(jq -r '.model' "$session_dir/session.json")
    local project_path=$(jq -r '.project_path' "$session_dir/session.json")

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}" >&2
    echo -e "${CYAN}LocalCode Query${NC} (Session: $session_id)" >&2
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}" >&2
    echo "" >&2

    # Build full context
    info "Building query context..."
    local full_context=$(build_query_context "$session_dir" "$question")

    # Show context size and warn if too large
    local context_size=$(echo "$full_context" | wc -c)
    local estimated_tokens=$((context_size / 4))
    info "Context size: $context_size bytes (~$estimated_tokens tokens)"

    # Warn if context is approaching or exceeding limits
    if [[ $estimated_tokens -gt 6000 ]]; then
        error "⚠️  Context TOO LARGE ($estimated_tokens tokens)! May fail with 8K window."
        error "    Reduce by: shortening question, clearing old tool results, or starting new session"
        return 1
    elif [[ $estimated_tokens -gt 4000 ]]; then
        warn "⚠️  Context large ($estimated_tokens tokens). Approaching 8K limit (~6K safe max)"
        warn "    Consider starting fresh session if responses slow or fail"
    elif [[ $estimated_tokens -gt 3000 ]]; then
        warn "Context moderate ($estimated_tokens tokens). Still safe for 8K window"
    fi

    # Query LLM
    local response=$(query_llm "$full_context" "$model")

    if [[ -z "$response" ]]; then
        error "No response from LLM"
        return 1
    fi

    # Check for tool requests
    local tool_requests=$(parse_tool_requests "$response" || echo "")

    if [[ -n "$tool_requests" ]]; then
        echo "" >&2
        warn "LLM requested tools:"
        echo "$tool_requests" >&2
        echo "" >&2

        # Execute tools and re-query
        local tool_results_text=""
        while IFS= read -r tool_call; do
            if [[ -n "$tool_call" ]]; then
                local result=$(execute_tool "$tool_call" "$session_dir")
                tool_results_text+="\n[TOOL RESULT: $tool_call]\n$result\n"
            fi
        done <<< "$tool_requests"

        # Re-query with tool results
        local updated_context=$(printf "%s\n\n## TOOL RESULTS\n%s\n\nNow answer the original question with this additional information." "$full_context" "$tool_results_text")
        response=$(query_llm "$updated_context" "$model")
    fi

    # Save turn
    save_turn "$session_dir" "$question" "$response"

    # Output response
    echo "" >&2
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}" >&2
    echo -e "${GREEN}Response from $model:${NC}" >&2
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}" >&2
    echo ""
    echo "$response"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}" >&2
}

# Interactive mode
interactive() {
    local session_id="$1"

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}LocalCode Interactive Mode${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Session: $session_id"
    echo "Type 'exit' to quit, 'help' for commands"
    echo ""

    while true; do
        echo -ne "${MAGENTA}localcode>${NC} "
        read -r input

        case "$input" in
            exit|quit)
                echo "Goodbye!"
                break
                ;;
            help)
                echo "Commands:"
                echo "  exit/quit - Exit interactive mode"
                echo "  help - Show this help"
                echo "  Any other text - Send as query to LLM"
                ;;
            "")
                continue
                ;;
            *)
                query "$session_id" "$input"
                ;;
        esac
        echo ""
    done
}

# Main CLI
main() {
    if [[ $# -lt 2 ]]; then
        cat <<EOF >&2
Usage: $0 <session_id> "<question>"
   or: $0 <session_id> --interactive

Examples:
  # Single query
  $0 session_20250111_123456 "What's the ECHO architecture?"

  # Interactive mode
  $0 session_20250111_123456 --interactive
EOF
        exit 1
    fi

    local session_id="$1"
    shift

    if [[ "$1" == "--interactive" ]] || [[ "$1" == "-i" ]]; then
        interactive "$session_id"
    else
        query "$session_id" "$*"
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
