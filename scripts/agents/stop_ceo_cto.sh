#!/bin/bash

# Stop CEO and CTO agents
# Usage: ./stop_ceo_cto.sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="$PROJECT_ROOT/logs/ceo_cto"

echo -e "${BLUE}Stopping CEO and CTO agents...${NC}"

# Read PIDs from file
if [ -f "$LOG_DIR/ceo.pid" ]; then
    CEO_PID=$(cat "$LOG_DIR/ceo.pid")
    if kill -0 "$CEO_PID" 2>/dev/null; then
        kill "$CEO_PID"
        echo -e "${GREEN}✓ CEO stopped (PID: $CEO_PID)${NC}"
    fi
    rm "$LOG_DIR/ceo.pid"
fi

if [ -f "$LOG_DIR/cto.pid" ]; then
    CTO_PID=$(cat "$LOG_DIR/cto.pid")
    if kill -0 "$CTO_PID" 2>/dev/null; then
        kill "$CTO_PID"
        echo -e "${GREEN}✓ CTO stopped (PID: $CTO_PID)${NC}"
    fi
    rm "$LOG_DIR/cto.pid"
fi

# Fallback: kill by process name
pkill -f "apps/ceo/ceo" 2>/dev/null && echo -e "${GREEN}✓ CEO process killed${NC}"
pkill -f "apps/cto/cto" 2>/dev/null && echo -e "${GREEN}✓ CTO process killed${NC}"

echo ""
echo -e "${GREEN}Agents stopped${NC}"
