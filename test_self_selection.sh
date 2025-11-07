#!/bin/bash

# Test Agent Self-Selection Feature
# Demonstrates dynamic participation evaluation

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REDIS_PORT=6383
DB_PORT=5433
DB_USER=echo_org
DB_NAME=echo_org
DB_PASSWORD=postgres

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Agent Self-Selection Test                               ║${NC}"
echo -e "${BLUE}║   Testing dynamic participation with LLM evaluation               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check infrastructure
echo -e "${BLUE}Checking infrastructure...${NC}"

if ! PGPASSWORD="$DB_PASSWORD" psql -h localhost -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${RED}✗ PostgreSQL not accessible${NC}"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL${NC}"

if ! redis-cli -p "$REDIS_PORT" ping > /dev/null 2>&1; then
    echo -e "${RED}✗ Redis not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Redis${NC}"

if ! ollama list > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Ollama not running (LLM features disabled)${NC}"
fi

# Start only CTO agent for focused test
echo ""
echo -e "${BLUE}Starting CTO agent...${NC}"

cd apps/cto
tail -f /dev/null | REDIS_PORT="$REDIS_PORT" REDIS_HOST=localhost DB_PORT="$DB_PORT" DB_USER="$DB_USER" DB_NAME="$DB_NAME" DB_PASSWORD="$DB_PASSWORD" ./cto > /tmp/cto_selfselect_test.log 2>&1 &
CTO_PID=$!

cd ../..

echo -e "${GREEN}✓ CTO running (PID: $CTO_PID)${NC}"

# Wait for startup
echo -e "${BLUE}Waiting for agent to initialize...${NC}"
sleep 3

# Send broadcast messages
echo ""
echo -e "${YELLOW}Test 1: Technical task (CTO should participate)${NC}"

redis-cli -p "$REDIS_PORT" PUBLISH "messages:all" "$(jq -n \
    --arg id "msg_test1_$(date +%s)" \
    --arg from "ceo" \
    --arg subject "Database performance optimization needed" \
    --arg content "We're experiencing slow queries in production. Need technical leadership to investigate and resolve." \
    '{
        id: $id,
        from: $from,
        to: "all",
        type: "task_broadcast",
        subject: $subject,
        content: $content,
        metadata: {
            timestamp: now | todate,
            priority: "high"
        }
    }')" > /dev/null

echo -e "  Broadcast: Database performance optimization"
sleep 2

echo ""
echo -e "${YELLOW}Test 2: HR task (CTO should decline)${NC}"

redis-cli -p "$REDIS_PORT" PUBLISH "messages:all" "$(jq -n \
    --arg id "msg_test2_$(date +%s)" \
    --arg from "ceo" \
    --arg subject "Hiring new HR manager" \
    --arg content "We need to recruit a new HR manager for the Boston office. Looking for candidates with 5+ years experience in HR management." \
    '{
        id: $id,
        from: $from,
        to: "all",
        type: "task_broadcast",
        subject: $subject,
        content: $content,
        metadata: {
            timestamp: now | todate,
            priority: "normal"
        }
    }')" > /dev/null

echo -e "  Broadcast: Hiring HR manager"
sleep 2

echo ""
echo -e "${YELLOW}Test 3: Mixed relevance (CTO should evaluate with LLM)${NC}"

redis-cli -p "$REDIS_PORT" PUBLISH "messages:all" "$(jq -n \
    --arg id "msg_test3_$(date +%s)" \
    --arg from "ceo" \
    --arg subject "How can AI agents develop curiosity?" \
    --arg content "Research question: Can we implement genuine curiosity in AI agents? This requires technical innovation but also understanding of learning psychology." \
    '{
        id: $id,
        from: $from,
        to: "all",
        type: "task_broadcast",
        subject: $subject,
        content: $content,
        metadata: {
            timestamp: now | todate,
            priority: "normal"
        }
    }')" > /dev/null

echo -e "  Broadcast: AI curiosity research"
sleep 3

# Show results
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Results:${NC}"
echo ""

# Extract participation decisions from log
echo -e "${GREEN}CTO Participation Decisions:${NC}"
echo ""

grep -E "Fast-path:|LLM decided:|participating|declining" /tmp/cto_selfselect_test.log 2>/dev/null | tail -20 || echo "  (No participation logs yet - check /tmp/cto_selfselect_test.log)"

echo ""
echo -e "${BLUE}Full log available at: /tmp/cto_selfselect_test.log${NC}"

# Cleanup
echo ""
echo -e "${BLUE}Stopping CTO agent...${NC}"
kill $CTO_PID 2>/dev/null || true
wait $CTO_PID 2>/dev/null || true
echo -e "${GREEN}✓ Test complete${NC}"

echo ""
echo -e "${YELLOW}Expected Behavior:${NC}"
echo -e "  Test 1: ${GREEN}CTO should PARTICIPATE${NC} (high keyword relevance + technical)"
echo -e "  Test 2: ${RED}CTO should DECLINE${NC} (HR-related, not technical)"
echo -e "  Test 3: ${BLUE}CTO should DEFER to LLM${NC} (ambiguous relevance)"
