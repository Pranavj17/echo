#!/bin/bash

# Quick system status check for ECHO

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  ECHO System Status Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# PostgreSQL
echo -e "${BLUE}PostgreSQL:${NC}"
if pgrep -f postgres > /dev/null; then
    echo -e "  ${GREEN}✓ Running${NC}"
    if psql -h localhost -U postgres -d echo_org_dev -c "SELECT COUNT(*) FROM messages;" 2>/dev/null | grep -q "row"; then
        MSG_COUNT=$(psql -h localhost -U postgres -d echo_org_dev -t -c "SELECT COUNT(*) FROM messages;" 2>/dev/null | tr -d ' ')
        DEC_COUNT=$(psql -h localhost -U postgres -d echo_org_dev -t -c "SELECT COUNT(*) FROM decisions;" 2>/dev/null | tr -d ' ')
        echo -e "  ${GREEN}✓ Database: echo_org_dev${NC}"
        echo -e "  ${BLUE}  Messages: $MSG_COUNT${NC}"
        echo -e "  ${BLUE}  Decisions: $DEC_COUNT${NC}"
    else
        echo -e "  ${YELLOW}⚠ Database not accessible${NC}"
    fi
else
    echo -e "  ${RED}✗ Not running${NC}"
fi
echo ""

# Redis
echo -e "${BLUE}Redis:${NC}"
if redis-cli ping &> /dev/null; then
    echo -e "  ${GREEN}✓ Running${NC}"
    REDIS_KEYS=$(redis-cli DBSIZE 2>/dev/null | grep -o '[0-9]*')
    echo -e "  ${BLUE}  Keys: $REDIS_KEYS${NC}"
else
    echo -e "  ${RED}✗ Not running${NC}"
fi
echo ""

# Ollama
echo -e "${BLUE}Ollama (LLM):${NC}"
if pgrep -f ollama > /dev/null; then
    echo -e "  ${GREEN}✓ Running${NC}"
    MODEL_COUNT=$(ollama list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
    echo -e "  ${BLUE}  Models: $MODEL_COUNT${NC}"
else
    echo -e "  ${YELLOW}⚠ Not running (LLM features disabled)${NC}"
fi
echo ""

# Agent Executables
echo -e "${BLUE}Agent Executables:${NC}"
AGENTS=("ceo" "cto" "chro" "operations_head" "product_manager" "senior_architect" "uiux_engineer" "senior_developer" "test_lead")
BUILT=0

for agent in "${AGENTS[@]}"; do
    if [ -f "apps/$agent/$agent" ]; then
        BUILT=$((BUILT + 1))
    fi
done

if [ $BUILT -eq 9 ]; then
    echo -e "  ${GREEN}✓ All 9 agents built${NC}"
else
    echo -e "  ${YELLOW}⚠ $BUILT / 9 agents built${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
POSTGRES_OK=$(pgrep -f postgres > /dev/null && echo "1" || echo "0")
REDIS_OK=$(redis-cli ping &> /dev/null && echo "1" || echo "0")
AGENTS_OK=$([ $BUILT -eq 9 ] && echo "1" || echo "0")

if [ "$POSTGRES_OK" = "1" ] && [ "$REDIS_OK" = "1" ] && [ "$AGENTS_OK" = "1" ]; then
    echo -e "${GREEN}✓ System ready for Day 1 simulation${NC}"
    echo ""
    echo "Run: ./run_day1_all_agents.sh"
else
    echo -e "${YELLOW}⚠ System not ready${NC}"
    echo ""
    [ "$POSTGRES_OK" = "0" ] && echo "  - Start PostgreSQL"
    [ "$REDIS_OK" = "0" ] && echo "  - Start Redis (brew services start redis)"
    [ "$AGENTS_OK" = "0" ] && echo "  - Build agents (./setup.sh)"
fi
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
