#!/bin/bash
# Ultra-fast verification that session_consult is integrated
# No LLM calls - just checks code and compilation

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Session Consult Integration Verification${NC}"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo ""

PASSED=0
FAILED=0
TOTAL=0

echo -e "${BLUE}Phase 1: Checking Shared Library${NC}"
echo ""

# Check Session module exists
echo -ne "  Session module... "
TOTAL=$((TOTAL + 1))
if grep -q "defmodule EchoShared.LLM.Session" "$PROJECT_ROOT/apps/echo_shared/lib/echo_shared/llm/session.ex"; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC}"
    FAILED=$((FAILED + 1))
fi

# Check ContextBuilder module exists
echo -ne "  ContextBuilder module... "
TOTAL=$((TOTAL + 1))
if grep -q "defmodule EchoShared.LLM.ContextBuilder" "$PROJECT_ROOT/apps/echo_shared/lib/echo_shared/llm/context_builder.ex"; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC}"
    FAILED=$((FAILED + 1))
fi

# Check DecisionHelper has consult_session
echo -ne "  DecisionHelper.consult_session... "
TOTAL=$((TOTAL + 1))
if grep -q "def consult_session" "$PROJECT_ROOT/apps/echo_shared/lib/echo_shared/llm/decision_helper.ex"; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC}"
    FAILED=$((FAILED + 1))
fi

# Check Application starts Session
echo -ne "  Application supervision... "
TOTAL=$((TOTAL + 1))
if grep -q "EchoShared.LLM.Session" "$PROJECT_ROOT/apps/echo_shared/lib/echo_shared/application.ex"; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC}"
    FAILED=$((FAILED + 1))
fi

echo ""
echo -e "${BLUE}Phase 2: Checking All 9 Agents${NC}"
echo ""

AGENTS=("ceo" "cto" "chro" "operations_head" "product_manager" "senior_architect" "uiux_engineer" "senior_developer" "test_lead")

for agent in "${AGENTS[@]}"; do
    echo -ne "  $agent... "
    TOTAL=$((TOTAL + 1))

    # Check tool definition exists
    if grep -q '"session_consult"' "$PROJECT_ROOT/apps/$agent/lib/$agent.ex"; then
        # Check execute handler exists
        if grep -q 'def execute_tool("session_consult"' "$PROJECT_ROOT/apps/$agent/lib/$agent.ex"; then
            # Check helper function exists
            if grep -q 'defp format_session_response' "$PROJECT_ROOT/apps/$agent/lib/$agent.ex"; then
                echo -e "${GREEN}✓${NC} (tool + handler + helper)"
                PASSED=$((PASSED + 1))
            else
                echo -e "${RED}✗${NC} (missing helper)"
                FAILED=$((FAILED + 1))
            fi
        else
            echo -e "${RED}✗${NC} (missing handler)"
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "${RED}✗${NC} (missing tool)"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo -e "${BLUE}Phase 3: Compilation Check${NC}"
echo ""

echo -ne "  Shared library compiles... "
TOTAL=$((TOTAL + 1))
if (cd "$PROJECT_ROOT/apps/echo_shared" && mix compile > /dev/null 2>&1); then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC}"
    FAILED=$((FAILED + 1))
fi

echo -ne "  All agents compile... "
COMPILE_OK=0
for agent in "${AGENTS[@]}"; do
    if ! (cd "$PROJECT_ROOT/apps/$agent" && mix compile > /dev/null 2>&1); then
        echo -e "${RED}✗${NC} ($agent failed)"
        COMPILE_OK=1
        break
    fi
done

TOTAL=$((TOTAL + 1))
if [ $COMPILE_OK -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi

echo ""
echo -e "${BLUE}Phase 4: Configuration Check${NC}"
echo ""

echo -ne "  LLM session config... "
TOTAL=$((TOTAL + 1))
if grep -q ":llm_session" "$PROJECT_ROOT/apps/echo_shared/config/dev.exs"; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC}"
    FAILED=$((FAILED + 1))
fi

echo -ne "  Agent models config... "
TOTAL=$((TOTAL + 1))
if grep -q ":agent_models" "$PROJECT_ROOT/apps/echo_shared/config/dev.exs"; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC}"
    FAILED=$((FAILED + 1))
fi

# Summary
echo ""
echo -e "${CYAN}════════════════════════════════════════════════${NC}"
PERCENT=$((PASSED * 100 / TOTAL))
echo -e "${BLUE}Results: ${GREEN}$PASSED/$TOTAL passed${NC} (${PERCENT}%)"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 SUCCESS! Session consult fully integrated!${NC}"
    echo ""
    echo -e "${CYAN}Integration complete:${NC}"
    echo -e "  ✓ Shared library modules"
    echo -e "  ✓ All 9 agents updated"
    echo -e "  ✓ Everything compiles"
    echo -e "  ✓ Configuration set"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  • Test with: cd apps/ceo && iex -S mix"
    echo -e "  • Then run: EchoShared.LLM.DecisionHelper.consult_session(:ceo, nil, \"Test\")"
    echo ""
    exit 0
else
    echo -e "${RED}⚠️  $FAILED/$TOTAL checks failed${NC}"
    echo ""
    exit 1
fi
