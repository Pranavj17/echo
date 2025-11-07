#!/bin/bash

# ECHO Agent Verification Script
# Comprehensive test of all 9 agents with autonomous mode

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    ECHO Agent Verification & Debugger Test           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

FAILURES=0
SUCCESSES=0

# Check infrastructure
echo -e "${BLUE}=== Infrastructure Checks ===${NC}"
echo ""

# PostgreSQL
if docker ps | grep -q echo-postgres; then
    echo -e "${GREEN}✓ PostgreSQL (Docker) running${NC}"
    ((SUCCESSES++))
else
    echo -e "${RED}✗ PostgreSQL NOT running${NC}"
    ((FAILURES++))
fi

# Redis
if redis-cli -p 6383 ping &> /dev/null; then
    echo -e "${GREEN}✓ Redis (port 6383) running${NC}"
    ((SUCCESSES++))
else
    echo -e "${RED}✗ Redis (port 6383) NOT running${NC}"
    ((FAILURES++))
fi

# Database user
if docker exec echo-postgres psql -U echo_org -d echo_org -c "SELECT 1" &> /dev/null; then
    echo -e "${GREEN}✓ Database user 'echo_org' exists${NC}"
    ((SUCCESSES++))
else
    echo -e "${RED}✗ Database user 'echo_org' does NOT exist${NC}"
    ((FAILURES++))
fi

# Ollama
if pgrep -f ollama > /dev/null; then
    echo -e "${GREEN}✓ Ollama running${NC}"
    ((SUCCESSES++))
else
    echo -e "${YELLOW}⚠ Ollama NOT running (LLM features disabled)${NC}"
fi

echo ""

# Check agent executables
echo -e "${BLUE}=== Agent Executable Checks ===${NC}"
echo ""

AGENTS=(ceo cto chro operations_head product_manager senior_architect uiux_engineer senior_developer test_lead)

for agent in "${AGENTS[@]}"; do
    AGENT_BIN="apps/$agent/$agent"
    if [ -f "$AGENT_BIN" ] && [ -x "$AGENT_BIN" ]; then
        echo -e "${GREEN}✓ $agent executable exists and is executable${NC}"
        ((SUCCESSES++))
    else
        echo -e "${RED}✗ $agent executable MISSING or not executable${NC}"
        ((FAILURES++))
    fi
done

echo ""

# Check autonomous mode support
echo -e "${BLUE}=== Autonomous Mode Support Checks ===${NC}"
echo ""

for agent in "${AGENTS[@]}"; do
    CLI_FILE="apps/$agent/lib/$agent/cli.ex"
    if grep -q "\\-\\-autonomous" "$CLI_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ $agent supports --autonomous mode${NC}"
        ((SUCCESSES++))
    else
        echo -e "${RED}✗ $agent MISSING --autonomous mode${NC}"
        ((FAILURES++))
    fi
done

echo ""

# Check message handler pattern
echo -e "${BLUE}=== Message Handler Pattern Checks ===${NC}"
echo ""

for agent in "${AGENTS[@]}"; do
    HANDLER_FILE="apps/$agent/lib/$agent/message_handler.ex"
    if grep -q "def handle_info({:redix_pubsub, _pid, _ref, :message" "$HANDLER_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ $agent has correct Redix pattern${NC}"
        ((SUCCESSES++))
    else
        echo -e "${RED}✗ $agent has INCORRECT Redix pattern${NC}"
        ((FAILURES++))
    fi
done

echo ""

# Runtime test - Start 3 agents and verify
echo -e "${BLUE}=== Runtime Verification Test ===${NC}"
echo ""

# Clear Redis
redis-cli -p 6383 FLUSHDB > /dev/null 2>&1
echo -e "${YELLOW}Redis cleared for test${NC}"
echo ""

# Start Senior Developer
echo -e "${YELLOW}Starting Senior Developer...${NC}"
cd apps/senior_developer
DB_USER=echo_org DB_PORT=5433 DB_NAME=echo_org REDIS_PORT=6383 ./senior_developer --autonomous > /tmp/verify_senior_dev.log 2>&1 &
SENIOR_DEV_PID=$!
cd ../..
sleep 8

# Check if running
if ps -p $SENIOR_DEV_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Senior Developer started (PID: $SENIOR_DEV_PID)${NC}"
    ((SUCCESSES++))
else
    echo -e "${RED}✗ Senior Developer FAILED to start${NC}"
    ((FAILURES++))
fi

# Check Redis subscription
SUBS=$(redis-cli -p 6383 PUBSUB NUMSUB messages:senior_developer | awk '{print $2}')
if [ "$SUBS" -gt 0 ]; then
    echo -e "${GREEN}✓ Senior Developer subscribed to Redis ($SUBS subscriber)${NC}"
    ((SUCCESSES++))
else
    echo -e "${RED}✗ Senior Developer NOT subscribed to Redis${NC}"
    ((FAILURES++))
fi

# Check database errors
sleep 3
DB_ERRORS=$(grep -c "failed to connect" /tmp/verify_senior_dev.log 2>/dev/null || echo "0")
if [ "$DB_ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✓ Senior Developer has 0 database errors${NC}"
    ((SUCCESSES++))
else
    echo -e "${RED}✗ Senior Developer has $DB_ERRORS database errors${NC}"
    ((FAILURES++))
fi

# Send test message
echo ""
echo -e "${YELLOW}Sending test message to Senior Developer...${NC}"
./send_message.sh senior_developer request verify_test '{"question": "Respond if you receive this"}' > /dev/null 2>&1
sleep 2

# Check if message was received
if grep -q "SENIOR_DEVELOPER received Redis message" /tmp/verify_senior_dev.log; then
    echo -e "${GREEN}✓ Senior Developer received test message${NC}"
    ((SUCCESSES++))
else
    echo -e "${RED}✗ Senior Developer did NOT receive test message${NC}"
    ((FAILURES++))
fi

# Start Product Manager
echo ""
echo -e "${YELLOW}Starting Product Manager...${NC}"
cd apps/product_manager
DB_USER=echo_org DB_PORT=5433 DB_NAME=echo_org REDIS_PORT=6383 ./product_manager --autonomous > /tmp/verify_product_mgr.log 2>&1 &
PRODUCT_MGR_PID=$!
cd ../..
sleep 8

# Check if running
if ps -p $PRODUCT_MGR_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Product Manager started (PID: $PRODUCT_MGR_PID)${NC}"
    ((SUCCESSES++))
else
    echo -e "${RED}✗ Product Manager FAILED to start${NC}"
    ((FAILURES++))
fi

# Check Redis subscription
SUBS=$(redis-cli -p 6383 PUBSUB NUMSUB messages:product_manager | awk '{print $2}')
if [ "$SUBS" -gt 0 ]; then
    echo -e "${GREEN}✓ Product Manager subscribed to Redis ($SUBS subscriber)${NC}"
    ((SUCCESSES++))
else
    echo -e "${RED}✗ Product Manager NOT subscribed to Redis${NC}"
    ((FAILURES++))
fi

# Test agent-to-agent communication
echo ""
echo -e "${YELLOW}Testing agent-to-agent communication...${NC}"
./send_message.sh product_manager request verify_comms '{"from": "senior_developer", "question": "Confirm reception"}' > /dev/null 2>&1
sleep 2

if grep -q "PRODUCT_MANAGER received Redis message" /tmp/verify_product_mgr.log; then
    echo -e "${GREEN}✓ Product Manager received message${NC}"
    ((SUCCESSES++))
else
    echo -e "${RED}✗ Product Manager did NOT receive message${NC}"
    ((FAILURES++))
fi

# Cleanup
echo ""
echo -e "${BLUE}Cleaning up test agents...${NC}"
kill $SENIOR_DEV_PID $PRODUCT_MGR_PID 2>/dev/null || true
wait $SENIOR_DEV_PID $PRODUCT_MGR_PID 2>/dev/null || true
echo -e "${GREEN}✓ Test agents stopped${NC}"

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Verification Results                     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Successes: $SUCCESSES${NC}"
echo -e "  ${RED}Failures:  $FAILURES${NC}"
echo ""

if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✓ ALL CHECKS PASSED - System Ready! 🎉            ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║   ⚠ Some checks failed - Review logs                ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Debug logs:"
    echo "  tail -f /tmp/verify_senior_dev.log"
    echo "  tail -f /tmp/verify_product_mgr.log"
    exit 1
fi
