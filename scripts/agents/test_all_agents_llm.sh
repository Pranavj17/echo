#!/bin/bash

# Test all ECHO agents' LLM integration
# Tests each agent's ability to communicate with its configured Ollama model

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Find script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# All agents
AGENTS=(
    "ceo"
    "cto"
    "chro"
    "operations_head"
    "product_manager"
    "senior_architect"
    "uiux_engineer"
    "senior_developer"
    "test_lead"
)

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ECHO Agent LLM Integration Test Suite               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Testing all 9 agents..."
echo ""

PASSED=0
FAILED=0
FAILED_AGENTS=()

for agent in "${AGENTS[@]}"; do
    echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
    echo -e "Testing: ${YELLOW}$agent${NC}"
    echo ""

    if "$SCRIPT_DIR/test_agent_llm.sh" "$agent" > /tmp/llm_test_${agent}.log 2>&1; then
        echo -e "${GREEN}✓ $agent passed${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ $agent failed${NC}"
        FAILED=$((FAILED + 1))
        FAILED_AGENTS+=("$agent")
        echo "See log: /tmp/llm_test_${agent}.log"
    fi
    echo ""
done

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Results:${NC}"
echo -e "${GREEN}  Passed: $PASSED / ${#AGENTS[@]}${NC}"
echo -e "${RED}  Failed: $FAILED / ${#AGENTS[@]}${NC}"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed agents:${NC}"
    for agent in "${FAILED_AGENTS[@]}"; do
        echo -e "  - $agent"
    done
    echo ""
    echo "Note: Large models (deepseek-coder:33b) may timeout on slower systems."
    echo "This is normal and doesn't indicate a problem with the integration."
    exit 1
else
    echo ""
    echo -e "${GREEN}🎉 All agents passed LLM integration tests!${NC}"
    exit 0
fi
