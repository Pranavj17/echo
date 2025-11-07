#!/bin/bash

# ECHO Autonomous Agents - Real Peer-to-Peer Mode
# Agents run independently and communicate via Redis message bus

set -e

# Disable echo alias if it exists (user may have aliased echo to start Claude)
unalias echo 2>/dev/null || true

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ECHO Autonomous Agents - Real Hierarchy Mode        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check infrastructure
echo -e "${BLUE}Checking infrastructure...${NC}"

if ! pgrep -f postgres > /dev/null; then
    echo -e "${RED}✗ PostgreSQL not running${NC}"
    exit 1
fi

if ! redis-cli ping &> /dev/null; then
    echo -e "${RED}✗ Redis not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PostgreSQL running${NC}"
echo -e "${GREEN}✓ Redis running${NC}"
echo ""

# Clear Redis for fresh start
echo -e "${BLUE}Clearing Redis message bus...${NC}"
redis-cli FLUSHDB > /dev/null 2>&1
echo -e "${GREEN}✓ Redis cleared${NC}"
echo ""

# Create log directory
LOG_DIR="$PROJECT_ROOT/logs/autonomous"
mkdir -p "$LOG_DIR"
echo -e "${BLUE}Logs directory: $LOG_DIR${NC}"
echo ""

# Start all agents
echo -e "${BLUE}Starting 9 autonomous agents...${NC}"
echo ""

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

PIDS=()

for agent in "${AGENTS[@]}"; do
    AGENT_BIN="$PROJECT_ROOT/apps/$agent/$agent"
    LOG_FILE="$LOG_DIR/${agent}.log"

    if [ ! -f "$AGENT_BIN" ]; then
        echo -e "${RED}✗ Agent not built: $agent${NC}"
        continue
    fi

    # Start agent in background with stdin kept open via tail -f /dev/null
    # This prevents the MCP server from exiting when stdin closes
    tail -f /dev/null | nohup "$AGENT_BIN" > "$LOG_FILE" 2>&1 &
    AGENT_PID=$!
    PIDS+=($AGENT_PID)

    echo -e "${GREEN}✓ $agent started (PID: $AGENT_PID)${NC}"

    # Store PID for later
    echo "$AGENT_PID" > "$LOG_DIR/${agent}.pid"

    sleep 0.5
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  All 9 agents running autonomously!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""

echo "Agents are now:"
echo "  ✓ Running in separate processes"
echo "  ✓ Subscribed to Redis message bus"
echo "  ✓ Listening for messages on their channels"
echo "  ✓ Ready to process requests autonomously"
echo ""

echo -e "${BLUE}To interact with agents:${NC}"
echo ""
echo "1. Send a message via Redis:"
echo "   redis-cli PUBLISH messages:ceo '{\"from\":\"product_manager\",\"type\":\"request\",\"subject\":\"approve_budget\",\"content\":{\"amount\":100000}}'"
echo ""
echo "2. Watch agent logs in real-time:"
echo "   tail -f $LOG_DIR/ceo.log"
echo "   tail -f $LOG_DIR/*.log  # All agents"
echo ""
echo "3. Monitor Redis messages:"
echo "   redis-cli PSUBSCRIBE 'messages:*'"
echo ""
echo "4. Check database activity:"
echo "   psql -h localhost -U postgres echo_org_dev -c 'SELECT * FROM messages ORDER BY inserted_at DESC LIMIT 10;'"
echo ""

echo -e "${YELLOW}Press Ctrl+C to stop all agents${NC}"
echo ""

# Store PIDs for cleanup
echo "${PIDS[@]}" > "$LOG_DIR/all_pids.txt"

# Trap Ctrl+C
trap cleanup INT TERM

cleanup() {
    echo ""
    echo -e "${BLUE}Stopping all agents...${NC}"

    for agent in "${AGENTS[@]}"; do
        PID_FILE="$LOG_DIR/${agent}.pid"
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                kill "$PID" 2>/dev/null || true
                echo -e "${GREEN}✓ Stopped $agent${NC}"
            fi
            rm "$PID_FILE"
        fi
    done

    rm -f "$LOG_DIR/all_pids.txt"

    echo ""
    echo -e "${GREEN}All agents stopped${NC}"
    echo "Logs saved to: $LOG_DIR"
    exit 0
}

# Keep running until Ctrl+C
while true; do
    sleep 1
done
