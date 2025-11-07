#!/bin/bash

# Start CEO and CTO agents for discussion
# Usage: ./start_ceo_cto.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      ECHO CEO-CTO Discussion Environment             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check Redis
if ! redis-cli ping &> /dev/null; then
    echo -e "${RED}✗ Redis is not running${NC}"
    echo "Starting Redis..."
    brew services start redis
    sleep 2
fi
echo -e "${GREEN}✓ Redis is running${NC}"

# Check PostgreSQL
if ! pgrep -f postgres > /dev/null; then
    echo -e "${RED}✗ PostgreSQL is not running${NC}"
    echo "Please start PostgreSQL and try again"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL is running${NC}"

# Check database exists
if ! psql -h localhost -U postgres -d echo_org_dev -c "SELECT 1" &> /dev/null; then
    echo -e "${YELLOW}⚠ Database echo_org_dev not found${NC}"
    echo "Creating database..."
    cd "$PROJECT_ROOT/shared"
    mix ecto.create
    mix ecto.migrate
    cd "$PROJECT_ROOT"
fi
echo -e "${GREEN}✓ Database ready${NC}"
echo ""

# Clear Redis message bus
echo -e "${BLUE}Clearing Redis message bus...${NC}"
redis-cli FLUSHDB > /dev/null 2>&1
echo -e "${GREEN}✓ Redis cleared${NC}"
echo ""

# Create log directory
LOG_DIR="$PROJECT_ROOT/logs/ceo_cto"
mkdir -p "$LOG_DIR"

# Kill any existing agent processes
pkill -f "apps/ceo/ceo" 2>/dev/null || true
pkill -f "apps/cto/cto" 2>/dev/null || true
sleep 1

# Start CEO
echo -e "${BLUE}Starting CEO agent...${NC}"
nohup "$PROJECT_ROOT/apps/ceo/ceo" > "$LOG_DIR/ceo.log" 2>&1 &
CEO_PID=$!
echo -e "${GREEN}✓ CEO started (PID: $CEO_PID)${NC}"

# Start CTO
echo -e "${BLUE}Starting CTO agent...${NC}"
nohup "$PROJECT_ROOT/apps/cto/cto" > "$LOG_DIR/cto.log" 2>&1 &
CTO_PID=$!
echo -e "${GREEN}✓ CTO started (PID: $CTO_PID)${NC}"

# Save PIDs to file for later cleanup
echo "$CEO_PID" > "$LOG_DIR/ceo.pid"
echo "$CTO_PID" > "$LOG_DIR/cto.pid"

echo ""
echo -e "${GREEN}Both agents are running!${NC}"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo "  CEO: tail -f $LOG_DIR/ceo.log"
echo "  CTO: tail -f $LOG_DIR/cto.log"
echo ""
echo -e "${BLUE}To stop agents:${NC}"
echo "  kill $CEO_PID $CTO_PID"
echo "  or run: ./stop_ceo_cto.sh"
echo ""
echo -e "${BLUE}To start a discussion:${NC}"
echo "  cd shared && mix run ../scripts/ceo_cto_discussion.exs"
echo ""
