#!/bin/bash
# Test script for ECHO agents - Validates MCP protocol communication

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${NC}"
echo -e "${BLUE}  ECHO Agent MCP Protocol Test${NC}"
echo -e "${BLUE}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${NC}"
echo ""

# Create test requests
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Valid JSON-RPC initialize request
cat > "$TEST_DIR/initialize.json" << 'EOF'
{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}},"id":1}
EOF

# Valid JSON-RPC tools/list request
cat > "$TEST_DIR/tools_list.json" << 'EOF'
{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}
EOF

# List of agents to test
AGENTS=("ceo" "cto" "chro" "operations_head" "product_manager" "senior_architect" "senior_developer" "test_lead" "uiux_engineer")

PASSED=0
FAILED=0
TOTAL=${#AGENTS[@]}

echo -e "${CYAN}Testing ${TOTAL} agents...${NC}"
echo ""

for agent in "${AGENTS[@]}"; do
    AGENT_PATH="apps/$agent/$agent"

    if [[ ! -x "$AGENT_PATH" ]]; then
        echo -e "${RED}✗ $agent${NC} - executable not found"
        ((FAILED++))
        continue
    fi

    echo -e "${YELLOW}Testing $agent...${NC}"

    # Test 1: Initialize
    echo -n "  1. Initialize request... "
    RESPONSE=$(timeout 5s cat "$TEST_DIR/initialize.json" | ./"$AGENT_PATH" 2>/dev/null | head -1)

    if echo "$RESPONSE" | jq -e '.result.capabilities' > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        INIT_PASS=true
    else
        echo -e "${RED}✗${NC}"
        echo "     Response: $RESPONSE"
        INIT_PASS=false
    fi

    # Test 2: Tools list
    echo -n "  2. Tools list request... "
    if [[ "$INIT_PASS" == true ]]; then
        # Send both initialize and tools/list
        RESPONSE=$(timeout 5s bash -c "cat '$TEST_DIR/initialize.json'; echo ''; cat '$TEST_DIR/tools_list.json'" | ./"$AGENT_PATH" 2>/dev/null | tail -1)

        if echo "$RESPONSE" | jq -e '.result.tools[]' > /dev/null 2>&1; then
            TOOL_COUNT=$(echo "$RESPONSE" | jq '.result.tools | length')
            echo -e "${GREEN}✓${NC} ($TOOL_COUNT tools)"
            TOOLS_PASS=true
        else
            echo -e "${RED}✗${NC}"
            echo "     Response: $RESPONSE"
            TOOLS_PASS=false
        fi
    else
        echo -e "${YELLOW}skipped${NC} (init failed)"
        TOOLS_PASS=false
    fi

    # Summary for this agent
    if [[ "$INIT_PASS" == true && "$TOOLS_PASS" == true ]]; then
        echo -e "  ${GREEN}✓ $agent: PASSED${NC}"
        ((PASSED++))
    else
        echo -e "  ${RED}✗ $agent: FAILED${NC}"
        ((FAILED++))
    fi
    echo ""
done

echo -e "${BLUE}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${NC}"
echo -e "${CYAN}  Test Summary${NC}"
echo -e "${BLUE}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${NC}"
echo ""
echo -e "  Total agents: ${TOTAL}"
echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
echo -e "  ${RED}Failed: ${FAILED}${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All agents are working correctly!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Run ./setup_claude_desktop.sh to configure Claude Desktop"
    echo "  2. Restart Claude Desktop"
    echo "  3. Start using ECHO agents!"
    exit 0
else
    echo -e "${RED}✗ Some agents failed tests${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  - Check if PostgreSQL is running: pg_isready"
    echo "  - Check if Redis is running: redis-cli ping"
    echo "  - Run migrations: cd shared && mix ecto.migrate"
    echo "  - View detailed logs by running agent directly:"
    echo "    echo '{\"jsonrpc\":\"2.0\",\"method\":\"initialize\",\"params\":{},\"id\":1}' | ./apps/ceo/ceo"
    exit 1
fi
