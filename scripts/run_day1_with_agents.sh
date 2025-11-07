#!/bin/bash

# ECHO Day 1 - Full Multi-Process Simulation
#
# This script runs all 9 agents as separate background processes
# and executes a Day 1 company introduction scenario with real
# agent coordination via Redis pub/sub.
#
# Each agent's logs are saved to separate files.

set -e

ECHO_ROOT="/Users/pranav/Documents/echo"
LOGS_DIR="$ECHO_ROOT/logs/day1_$(date +%Y%m%d_%H%M%S)"
PIDS_FILE="$ECHO_ROOT/.day1_pids"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================================================================"
echo "ECHO Day 1 - Company Introduction Simulation"
echo "================================================================================"
echo ""

# Create logs directory
mkdir -p "$LOGS_DIR"
echo -e "${GREEN}✓ Created logs directory: $LOGS_DIR${NC}"

# Clean up function
cleanup() {
    echo ""
    echo "================================================================================"
    echo "Stopping all agents..."
    echo "================================================================================"

    if [ -f "$PIDS_FILE" ]; then
        while read pid; do
            if kill -0 "$pid" 2>/dev/null; then
                echo "Stopping process $pid"
                kill "$pid" 2>/dev/null || true
            fi
        done < "$PIDS_FILE"
        rm "$PIDS_FILE"
    fi

    echo ""
    echo -e "${GREEN}All agents stopped. Logs saved to: $LOGS_DIR${NC}"
    echo ""
    echo "View logs:"
    echo "  tail -f $LOGS_DIR/ceo.log"
    echo "  tail -f $LOGS_DIR/cto.log"
    echo "  ... etc"
    echo ""
}

trap cleanup EXIT INT TERM

# Check prerequisites
echo "Checking prerequisites..."
if ! pg_isready -h localhost >/dev/null 2>&1; then
    echo -e "${RED}✗ PostgreSQL not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL running${NC}"

if ! redis-cli ping >/dev/null 2>&1; then
    echo -e "${RED}✗ Redis not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Redis running${NC}"

echo ""
echo "================================================================================"
echo "Starting ECHO Agents (9 separate processes)"
echo "================================================================================"
echo ""

# Agent list - simple arrays (bash 3.2 compatible)
AGENT_NAMES=(ceo cto chro operations_head product_manager senior_architect uiux_engineer senior_developer test_lead)
AGENT_TITLES=(
    "Chief Executive Officer"
    "Chief Technology Officer"
    "Chief Human Resources Officer"
    "Operations Head"
    "Product Manager"
    "Senior Architect"
    "UI/UX Engineer"
    "Senior Developer"
    "Test Lead"
)

# Clean previous PID file
rm -f "$PIDS_FILE"

# Start each agent as background process with daemon mode simulation
for i in "${!AGENT_NAMES[@]}"; do
    agent="${AGENT_NAMES[$i]}"
    title="${AGENT_TITLES[$i]}"
    AGENT_DIR="$ECHO_ROOT/apps/$agent"
    AGENT_BIN="$AGENT_DIR/$agent"
    LOG_FILE="$LOGS_DIR/${agent}.log"

    echo -e "${BLUE}Starting $agent ($title)...${NC}"

    # Start agent with continuous input stream (keeps it alive)
    # This is a workaround - agents expect stdin, so we pipe yes output to keep them running
    (
        cd "$AGENT_DIR"
        # Send initialize message first, then keep sending empty lines
        {
            echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"day1-simulation","version":"1.0"}}}'
            sleep 1
            # Keep process alive with periodic pings
            while true; do
                echo '{"jsonrpc":"2.0","method":"ping"}'
                sleep 5
            done
        } | "$AGENT_BIN" > "$LOG_FILE" 2>&1
    ) &

    PID=$!
    echo "$PID" >> "$PIDS_FILE"
    echo -e "${GREEN}  ✓ Started with PID: $PID${NC}"
    echo -e "     Log: $LOG_FILE"
    echo ""

    # Wait a bit before starting next agent
    sleep 0.5
done

echo "================================================================================"
echo -e "${GREEN}All 9 agents started successfully!${NC}"
echo "================================================================================"
echo ""

# Wait for agents to fully initialize
echo "Waiting for agents to initialize..."
sleep 3
echo ""

# Verify agents are running
echo "================================================================================"
echo "Agent Status Check"
echo "================================================================================"
echo ""

RUNNING=0
while read pid; do
    if kill -0 "$pid" 2>/dev/null; then
        RUNNING=$((RUNNING + 1))
    fi
done < "$PIDS_FILE"

echo -e "${GREEN}✓ $RUNNING/9 agents running${NC}"
echo ""

if [ $RUNNING -lt 9 ]; then
    echo -e "${YELLOW}⚠ Some agents failed to start. Check logs.${NC}"
    echo ""
fi

# Show live logs
echo "================================================================================"
echo "Live Agent Logs (Press Ctrl+C to stop)"
echo "================================================================================"
echo ""
echo "Opening log viewer in 3 seconds..."
echo "You can also manually view logs:"
echo ""
for agent in "${AGENT_NAMES[@]}"; do
    echo "  tail -f $LOGS_DIR/${agent}.log"
done
echo ""

sleep 3

# Show logs from all agents using multitail if available, otherwise use tail
if command -v multitail >/dev/null 2>&1; then
    multitail \
        -l "tail -f $LOGS_DIR/ceo.log" \
        -l "tail -f $LOGS_DIR/cto.log" \
        -l "tail -f $LOGS_DIR/chro.log" \
        -l "tail -f $LOGS_DIR/operations_head.log" \
        -l "tail -f $LOGS_DIR/product_manager.log" \
        -l "tail -f $LOGS_DIR/senior_architect.log" \
        -l "tail -f $LOGS_DIR/uiux_engineer.log" \
        -l "tail -f $LOGS_DIR/senior_developer.log" \
        -l "tail -f $LOGS_DIR/test_lead.log"
else
    # Fallback: show one log file
    echo -e "${YELLOW}Note: Install 'multitail' to view all logs simultaneously${NC}"
    echo "      brew install multitail"
    echo ""
    echo "Showing CEO log (use other terminals to view other agents):"
    echo ""
    tail -f "$LOGS_DIR/ceo.log"
fi
