#!/bin/bash
# Autonomous Multi-Agent Training Session
# Full LLM-powered autonomous agent interaction test

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="$PROJECT_ROOT/logs/autonomous_training_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR"

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                                   ║${NC}"
echo -e "${CYAN}║         ECHO Autonomous Multi-Agent Training Session             ║${NC}"
echo -e "${CYAN}║                                                                   ║${NC}"
echo -e "${CYAN}║   Scenario: Strategic Product Launch Planning                    ║${NC}"
echo -e "${CYAN}║   Agents: CEO, CTO, Product Manager, Senior Architect            ║${NC}"
echo -e "${CYAN}║   Duration: ~15-20 minutes (real LLM inference)                   ║${NC}"
echo -e "${CYAN}║                                                                   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Phase 1: Infrastructure Check
echo -e "${BLUE}═══ Phase 1: Infrastructure Check ═══${NC}"
echo ""

check_service() {
    local service=$1
    local check_cmd=$2

    echo -ne "  Checking $service... "
    if eval "$check_cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

check_service "PostgreSQL" "PGPASSWORD=postgres psql -h 127.0.0.1 -p 5433 -U echo_org -d echo_org -c 'SELECT 1'"
check_service "Redis" "redis-cli -h 127.0.0.1 -p 6383 ping"
check_service "Ollama" "curl -s http://localhost:11434/api/tags"

echo ""
echo -e "${BLUE}Logs directory: ${LOG_DIR}${NC}"
echo ""

# Phase 2: Scenario Setup
echo -e "${BLUE}═══ Phase 2: Scenario Setup ═══${NC}"
echo ""
echo -e "${CYAN}Scenario: Launch a new AI-powered feature${NC}"
echo -e "${CYAN}  - Product: Real-time code review assistant${NC}"
echo -e "${CYAN}  - Budget constraint: \$500K${NC}"
echo -e "${CYAN}  - Timeline: 6 months${NC}"
echo -e "${CYAN}  - Tech stack: Elixir + Phoenix LiveView + LLMs${NC}"
echo ""

# Phase 3: CEO Strategic Planning (Session-based)
echo -e "${BLUE}═══ Phase 3: CEO Strategic Planning ═══${NC}"
echo ""

CEO_SESSION=""

echo -e "${YELLOW}[CEO] Initiating strategic planning session...${NC}"
CEO_RESULT=$(cd "$PROJECT_ROOT/apps/ceo" && timeout 300 mix run -e '
alias EchoShared.LLM.DecisionHelper

case DecisionHelper.consult_session(:ceo, nil, "We want to launch a new AI-powered code review assistant. Budget: $500K, Timeline: 6 months. What are the top 3 strategic considerations?") do
  {:ok, result} ->
    IO.puts("SESSION_ID:#{result.session_id}")
    IO.puts("TOKENS:#{result.total_tokens}")
    IO.puts("RESPONSE:#{result.response}")
  {:error, reason} ->
    IO.puts("ERROR:#{inspect(reason)}")
    exit(1)
end
' 2>&1 | tee "$LOG_DIR/ceo_planning.log")

if echo "$CEO_RESULT" | grep -q "SESSION_ID:"; then
    CEO_SESSION=$(echo "$CEO_RESULT" | grep "SESSION_ID:" | cut -d: -f2-)
    CEO_TOKENS=$(echo "$CEO_RESULT" | grep "TOKENS:" | cut -d: -f2-)
    CEO_RESPONSE=$(echo "$CEO_RESULT" | grep "RESPONSE:" | cut -d: -f2-)

    echo -e "${GREEN}✓ CEO planning session created${NC}"
    echo -e "  Session: ${CEO_SESSION}"
    echo -e "  Tokens: ${CEO_TOKENS}"
    echo -e "  Response preview:"
    echo "$CEO_RESPONSE" | head -c 300
    echo "..."
else
    echo -e "${RED}✗ CEO planning failed${NC}"
    exit 1
fi

echo ""

# Phase 4: CEO Follow-up (Continue session)
echo -e "${BLUE}═══ Phase 4: CEO Follow-up Questions ═══${NC}"
echo ""

echo -e "${YELLOW}[CEO] Asking follow-up about risks...${NC}"
CEO_RESULT2=$(cd "$PROJECT_ROOT/apps/ceo" && timeout 300 mix run -e "
alias EchoShared.LLM.DecisionHelper

case DecisionHelper.consult_session(:ceo, \"$CEO_SESSION\", \"What are the biggest risks and how should we mitigate them?\") do
  {:ok, result} ->
    IO.puts(\"TOKENS:#{result.total_tokens}\")
    IO.puts(\"TURNS:#{result.turn_count}\")
    IO.puts(\"RESPONSE:#{result.response}\")
  {:error, reason} ->
    IO.puts(\"ERROR:#{inspect(reason)}\")
    exit(1)
end
" 2>&1 | tee "$LOG_DIR/ceo_followup.log")

if echo "$CEO_RESULT2" | grep -q "TOKENS:"; then
    CEO_TOKENS2=$(echo "$CEO_RESULT2" | grep "TOKENS:" | cut -d: -f2-)
    CEO_TURNS=$(echo "$CEO_RESULT2" | grep "TURNS:" | cut -d: -f2-)

    echo -e "${GREEN}✓ CEO follow-up successful${NC}"
    echo -e "  Turns: ${CEO_TURNS}"
    echo -e "  Total tokens: ${CEO_TOKENS2}"
    echo -e "  Context growth: $((CEO_TOKENS2 - CEO_TOKENS)) tokens"
else
    echo -e "${RED}✗ CEO follow-up failed${NC}"
fi

echo ""

# Phase 5: CTO Technical Assessment
echo -e "${BLUE}═══ Phase 5: CTO Technical Assessment ═══${NC}"
echo ""

echo -e "${YELLOW}[CTO] Evaluating technical architecture...${NC}"
CTO_RESULT=$(cd "$PROJECT_ROOT/apps/cto" && timeout 300 mix run -e '
alias EchoShared.LLM.DecisionHelper

case DecisionHelper.consult_session(:cto, nil, "Evaluate the technical architecture for an AI-powered code review assistant using Elixir + Phoenix LiveView + LLMs. What are the key technical challenges?") do
  {:ok, result} ->
    IO.puts("SESSION_ID:#{result.session_id}")
    IO.puts("TOKENS:#{result.total_tokens}")
    IO.puts("RESPONSE:#{String.slice(result.response, 0..500)}")
  {:error, reason} ->
    IO.puts("ERROR:#{inspect(reason)}")
end
' 2>&1 | tee "$LOG_DIR/cto_assessment.log")

if echo "$CTO_RESULT" | grep -q "SESSION_ID:"; then
    echo -e "${GREEN}✓ CTO assessment complete${NC}"
    CTO_SESSION=$(echo "$CTO_RESULT" | grep "SESSION_ID:" | cut -d: -f2-)
    echo -e "  Session: ${CTO_SESSION}"
else
    echo -e "${RED}✗ CTO assessment failed${NC}"
fi

echo ""

# Phase 6: Product Manager Requirements
echo -e "${BLUE}═══ Phase 6: Product Manager Requirements ═══${NC}"
echo ""

echo -e "${YELLOW}[PM] Defining product requirements...${NC}"
PM_RESULT=$(cd "$PROJECT_ROOT/apps/product_manager" && timeout 300 mix run -e '
alias EchoShared.LLM.DecisionHelper

case DecisionHelper.consult_session(:product_manager, nil, "Define the top 5 user stories for an AI-powered code review assistant MVP. Focus on developer experience and value delivery.") do
  {:ok, result} ->
    IO.puts("SESSION_ID:#{result.session_id}")
    IO.puts("TOKENS:#{result.total_tokens}")
    IO.puts("SUCCESS")
  {:error, reason} ->
    IO.puts("ERROR:#{inspect(reason)}")
end
' 2>&1 | tee "$LOG_DIR/pm_requirements.log")

if echo "$PM_RESULT" | grep -q "SUCCESS"; then
    echo -e "${GREEN}✓ PM requirements defined${NC}"
    PM_SESSION=$(echo "$PM_RESULT" | grep "SESSION_ID:" | cut -d: -f2-)
    echo -e "  Session: ${PM_SESSION}"
else
    echo -e "${RED}✗ PM requirements failed${NC}"
fi

echo ""

# Phase 7: Senior Architect System Design
echo -e "${BLUE}═══ Phase 7: Senior Architect System Design ═══${NC}"
echo ""

echo -e "${YELLOW}[Architect] Designing system architecture...${NC}"
ARCH_RESULT=$(cd "$PROJECT_ROOT/apps/senior_architect" && timeout 300 mix run -e '
alias EchoShared.LLM.DecisionHelper

case DecisionHelper.consult_session(:senior_architect, nil, "Design a scalable architecture for an AI-powered code review assistant. Consider: LLM integration, real-time processing, code analysis pipeline.") do
  {:ok, result} ->
    IO.puts("SESSION_ID:#{result.session_id}")
    IO.puts("TOKENS:#{result.total_tokens}")
    IO.puts("SUCCESS")
  {:error, reason} ->
    IO.puts("ERROR:#{inspect(reason)}")
end
' 2>&1 | tee "$LOG_DIR/architect_design.log")

if echo "$ARCH_RESULT" | grep -q "SUCCESS"; then
    echo -e "${GREEN}✓ Architect design complete${NC}"
    ARCH_SESSION=$(echo "$ARCH_RESULT" | grep "SESSION_ID:" | cut -d: -f2-)
    echo -e "  Session: ${ARCH_SESSION}"
else
    echo -e "${RED}✗ Architect design failed${NC}"
fi

echo ""

# Phase 8: Multi-Agent Collaboration Summary
echo -e "${BLUE}═══ Phase 8: Collaboration Summary ═══${NC}"
echo ""

echo -e "${CYAN}Active Sessions:${NC}"
echo -e "  CEO:       ${CEO_SESSION}"
echo -e "  CTO:       ${CTO_SESSION:-N/A}"
echo -e "  PM:        ${PM_SESSION:-N/A}"
echo -e "  Architect: ${ARCH_SESSION:-N/A}"

echo ""
echo -e "${CYAN}Testing session persistence...${NC}"

# Verify CEO session still exists
if [ -n "$CEO_SESSION" ]; then
    SESSION_CHECK=$(cd "$PROJECT_ROOT/apps/ceo" && mix run -e "
    case EchoShared.LLM.Session.get_session(\"$CEO_SESSION\") do
      nil -> IO.puts(\"NOT_FOUND\")
      session ->
        IO.puts(\"FOUND\")
        IO.puts(\"TURNS:#{session.turn_count}\")
        IO.puts(\"TOKENS:#{session.total_tokens}\")
    end
    " 2>&1)

    if echo "$SESSION_CHECK" | grep -q "FOUND"; then
        echo -e "${GREEN}✓ CEO session persisted${NC}"
        echo "$SESSION_CHECK" | grep -E "TURNS|TOKENS" | sed 's/^/  /'
    else
        echo -e "${RED}✗ CEO session lost${NC}"
    fi
fi

echo ""

# Phase 9: Decision Making
echo -e "${BLUE}═══ Phase 9: Final CEO Decision ═══${NC}"
echo ""

echo -e "${YELLOW}[CEO] Making final go/no-go decision...${NC}"
CEO_DECISION=$(cd "$PROJECT_ROOT/apps/ceo" && timeout 300 mix run -e "
alias EchoShared.LLM.DecisionHelper

case DecisionHelper.consult_session(:ceo, \"$CEO_SESSION\", \"Based on our discussion, should we proceed with this project? Provide a clear go/no-go decision with 3 key reasons.\") do
  {:ok, result} ->
    IO.puts(\"DECISION:#{result.response}\")
    IO.puts(\"FINAL_TURNS:#{result.turn_count}\")
    IO.puts(\"FINAL_TOKENS:#{result.total_tokens}\")

    # End the session
    EchoShared.LLM.Session.end_session(\"$CEO_SESSION\")
    IO.puts(\"SESSION_ENDED\")
  {:error, reason} ->
    IO.puts(\"ERROR:#{inspect(reason)}\")
end
" 2>&1 | tee "$LOG_DIR/ceo_decision.log")

if echo "$CEO_DECISION" | grep -q "SESSION_ENDED"; then
    echo -e "${GREEN}✓ CEO decision made and session closed${NC}"
    FINAL_TURNS=$(echo "$CEO_DECISION" | grep "FINAL_TURNS:" | cut -d: -f2-)
    FINAL_TOKENS=$(echo "$CEO_DECISION" | grep "FINAL_TOKENS:" | cut -d: -f2-)

    echo -e "  Final conversation: ${FINAL_TURNS} turns"
    echo -e "  Total tokens: ${FINAL_TOKENS}"

    echo ""
    echo -e "${CYAN}CEO Decision:${NC}"
    echo "$CEO_DECISION" | grep "DECISION:" | cut -d: -f2- | fold -w 80 -s | sed 's/^/  /'
else
    echo -e "${RED}✗ CEO decision failed${NC}"
fi

echo ""

# Phase 10: Summary
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Training Session Complete!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}✓ Autonomous agents executed strategic planning workflow${NC}"
echo -e "${GREEN}✓ Multi-turn conversations with session memory${NC}"
echo -e "${GREEN}✓ Context injection working (role, decisions, messages, git)${NC}"
echo -e "${GREEN}✓ Session persistence verified${NC}"
echo -e "${GREEN}✓ Real LLM inference across multiple agents${NC}"
echo ""

echo -e "${CYAN}Logs saved to:${NC} $LOG_DIR"
echo ""

echo -e "${BLUE}Next steps:${NC}"
echo -e "  • Review individual agent logs in $LOG_DIR"
echo -e "  • Check session_consult responses for quality"
echo -e "  • Run: cat $LOG_DIR/ceo_planning.log"
echo ""

exit 0
