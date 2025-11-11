#!/bin/bash
# Quick Session Consult Test - Fast verification across all agents
# Tests basic functionality without full LLM queries

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Quick Session Consult Test${NC}"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo ""

PASSED=0
FAILED=0

# Test CEO in detail (full LLM test)
echo -e "${BLUE}[1/9] Testing CEO (full LLM test)...${NC}"
RESULT=$(cd "$PROJECT_ROOT/apps/ceo" && timeout 60 mix run -e '
  alias EchoShared.LLM.DecisionHelper

  # Test 1: Create session
  case DecisionHelper.consult_session(:ceo, nil, "What is my role?") do
    {:ok, r1} ->
      # Test 2: Continue
      case DecisionHelper.consult_session(:ceo, r1.session_id, "What are my priorities?") do
        {:ok, r2} ->
          IO.puts("SUCCESS:session=#{r2.session_id},turns=#{r2.turn_count},tokens=#{r2.total_tokens}")
          EchoShared.LLM.Session.end_session(r2.session_id)
        _ -> IO.puts("FAIL:continuation")
      end
    _ -> IO.puts("FAIL:creation")
  end
' 2>&1 | grep -E "(SUCCESS|FAIL)")

if echo "$RESULT" | grep -q "SUCCESS"; then
    echo -e "  ${GREEN}✓ CEO passed${NC}"
    SESSION_ID=$(echo "$RESULT" | grep -oP 'session=\K[^,]+')
    TURNS=$(echo "$RESULT" | grep -oP 'turns=\K[^,]+')
    TOKENS=$(echo "$RESULT" | grep -oP 'tokens=\K[^,]+')
    echo -e "    Session: $SESSION_ID"
    echo -e "    Turns: $TURNS, Tokens: $TOKENS"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗ CEO failed${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test other agents (compilation + basic API test)
for agent in cto chro operations_head product_manager senior_architect uiux_engineer senior_developer test_lead; do
    AGENT_NUM=$((PASSED + FAILED + 1))
    echo -e "${BLUE}[$AGENT_NUM/9] Testing $agent (API test)...${NC}"

    # Just verify the tool exists and API works (no LLM call)
    RESULT=$(cd "$PROJECT_ROOT/apps/$agent" && timeout 30 mix run -e "
      alias EchoShared.LLM.{Config, Session}

      # Verify model configured
      model = Config.get_model(:$agent)
      IO.puts(\"MODEL:#{model}\")

      # Verify Session module accessible
      sessions = Session.list_sessions()
      IO.puts(\"SESSIONS:#{length(sessions)}\")

      IO.puts(\"SUCCESS\")
    " 2>&1 | grep -E "(SUCCESS|MODEL|ERROR)")

    if echo "$RESULT" | grep -q "SUCCESS"; then
        echo -e "  ${GREEN}✓ $agent passed${NC}"
        MODEL=$(echo "$RESULT" | grep "MODEL:" | cut -d: -f2-)
        echo -e "    Model: $MODEL"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ $agent failed${NC}"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

# Summary
echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Results: ${GREEN}$PASSED passed${NC} | ${RED}$FAILED failed${NC}"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed.${NC}"
    exit 1
fi
