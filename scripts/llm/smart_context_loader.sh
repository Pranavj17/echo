#!/usr/bin/env bash
# Smart Context Loader for LocalCode
# Detects keywords in queries and loads relevant claude.md files

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Color output
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[Smart Context]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[Smart Context]${NC} $1" >&2
}

# Keyword to claude.md mapping
# Format: "keyword1|keyword2:path/to/claude.md:priority"
declare -a KEYWORD_MAPS=(
    # Agents & Development
    "agent|agents|ceo|cto|chro:apps/claude.md:high"
    "delegator|resource|optimization:apps/delegator/claude.md:high"
    "shared|library|messageBus|decision:apps/echo_shared/claude.md:medium"

    # Testing
    "test|testing|integration|e2e|fixture:test/claude.md:high"
    "benchmark|performance|llm|model:benchmark_models/claude.md:medium"

    # Development Tools
    "script|localcode|lc_query|lc_start:scripts/claude.md:medium"
    "training|day2|day3:training/claude.md:low"

    # Workflows & Monitoring
    "workflow|orchestration|flow:workflows/claude.md:medium"
    "monitor|dashboard|phoenix|liveview:monitor/claude.md:medium"

    # Deployment
    "docker|container|compose:docker/claude.md:medium"
    "kubernetes|k8s|kubectl|helm:k8s/claude.md:medium"

    # Troubleshooting
    "database|postgres|psql|migration:docs/snippets/database_troubleshooting.md:high"
    "ollama|model|inference|timeout:docs/snippets/ollama_troubleshooting.md:high"
    "git|commit|pr|pull request:docs/snippets/git_workflow.md:low"
)

# Detect keywords in query
detect_keywords() {
    local query="$1"
    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    declare -a detected_files=()
    declare -a priorities=()

    for mapping in "${KEYWORD_MAPS[@]}"; do
        local keywords=$(echo "$mapping" | cut -d: -f1)
        local file_path=$(echo "$mapping" | cut -d: -f2)
        local priority=$(echo "$mapping" | cut -d: -f3)

        # Check if any keyword matches
        IFS='|' read -ra KW_ARRAY <<< "$keywords"
        for keyword in "${KW_ARRAY[@]}"; do
            if echo "$query_lower" | grep -qw "$keyword"; then
                detected_files+=("$file_path")
                priorities+=("$priority")
                break  # Only add file once per mapping
            fi
        done
    done

    # Remove duplicates while preserving order
    declare -a unique_files=()
    for file in "${detected_files[@]}"; do
        if [[ ! " ${unique_files[@]} " =~ " ${file} " ]]; then
            unique_files+=("$file")
        fi
    done

    # Return detected files
    printf '%s\n' "${unique_files[@]}"
}

# Load relevant claude.md content (condensed)
load_relevant_context() {
    local file_path="$1"
    local full_path="$PROJECT_ROOT/$file_path"

    if [[ ! -f "$full_path" ]]; then
        warn "File not found: $file_path"
        return
    fi

    # Load first 50 lines (condensed context) or specific sections
    local filename=$(basename "$file_path")

    echo "# Context from $filename"
    echo ""

    case "$filename" in
        "claude.md")
            # Load Purpose + Quick Start (first 80 lines typically)
            head -80 "$full_path" | grep -A 100 "## Purpose" | head -60
            ;;
        "database_troubleshooting.md"|"ollama_troubleshooting.md"|"testing_commands.md"|"git_workflow.md")
            # Load full snippet (these are already condensed)
            cat "$full_path"
            ;;
        *)
            # Load first 50 lines as default
            head -50 "$full_path"
            ;;
    esac

    echo ""
    echo "---"
    echo ""
}

# Build smart context for query
build_smart_context() {
    local query="$1"
    local max_files="${2:-3}"  # Limit to avoid context overflow

    info "Analyzing query for relevant context..."

    local detected_files=$(detect_keywords "$query")

    if [[ -z "$detected_files" ]]; then
        warn "No specific keywords detected. Using base context."
        return 0
    fi

    local file_count=0
    echo "$detected_files" | while read -r file_path; do
        if [[ $file_count -ge $max_files ]]; then
            warn "Reached max context files limit ($max_files). Skipping remaining."
            break
        fi

        info "Loading context from: $file_path"
        load_relevant_context "$file_path"

        ((file_count++))
    done
}

# Main entry point
main() {
    local query="${1:-}"
    local max_files="${2:-3}"

    if [[ -z "$query" ]]; then
        echo "Usage: $0 <query> [max_files]"
        echo ""
        echo "Detects keywords and loads relevant claude.md context."
        echo ""
        echo "Examples:"
        echo "  $0 'How do agents communicate?'  # Loads apps/claude.md"
        echo "  $0 'Fix database connection'     # Loads docs/snippets/database_troubleshooting.md"
        echo "  $0 'Deploy to Kubernetes'         # Loads k8s/claude.md"
        exit 1
    fi

    build_smart_context "$query" "$max_files"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
