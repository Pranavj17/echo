#!/bin/bash

# ECHO - Start All Agents
#
# This script starts all 9 ECHO agents as background processes.
# Each agent runs as a separate MCP server listening on stdin/stdout.
#
# Prerequisites:
# - PostgreSQL running (localhost:5432)
# - Redis running (localhost:6379)
# - All agent escripts built
#
# Usage:
#   ./scripts/start_all_agents.sh

set -e

ECHO_ROOT="/Users/pranav/Documents/echo"
AGENTS_DIR="$ECHO_ROOT/agents"
PIDS_FILE="$ECHO_ROOT/.agent_pids"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================================================"
echo "ECHO - Starting All Agents"
echo "================================================================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Check PostgreSQL
if ! pg_isready -h localhost >/dev/null 2>&1; then
    echo -e "${RED}✗ PostgreSQL is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL is running${NC}"

# Check Redis
if ! redis-cli ping >/dev/null 2>&1; then
    echo -e "${RED}✗ Redis is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Redis is running${NC}"

# Check database exists
if ! psql -h localhost -U postgres -lqt | cut -d \| -f 1 | grep -qw echo_org; then
    echo -e "${RED}✗ Database 'echo_org' does not exist${NC}"
    echo "  Run: cd shared && mix ecto.create && mix ecto.migrate"
    exit 1
fi
echo -e "${GREEN}✓ Database 'echo_org' exists${NC}"

echo ""

# Clean up previous PIDs file
rm -f "$PIDS_FILE"

# Start each agent
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

echo "Starting agents..."
echo ""

for agent in "${AGENTS[@]}"; do
    AGENT_DIR="$AGENTS_DIR/$agent"
    AGENT_BIN="$AGENT_DIR/$agent"
    LOG_FILE="$ECHO_ROOT/logs/${agent}.log"

    # Check if escript exists
    if [ ! -f "$AGENT_BIN" ]; then
        echo -e "${RED}✗ Agent escript not found: $AGENT_BIN${NC}"
        echo "  Run: cd $AGENT_DIR && mix escript.build"
        exit 1
    fi

    # Create logs directory if needed
    mkdir -p "$ECHO_ROOT/logs"

    # Start agent in background
    # NOTE: MCP agents use stdin/stdout, so we can't truly background them
    # This is a simplified version - in production, agents would be managed differently
    echo -e "${YELLOW}⧗ Starting $agent...${NC}"

    # For now, just verify the agent can initialize
    # Real deployment would use systemd, Docker, or k8s
    if timeout 3 bash -c "echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0\"}}}' | $AGENT_BIN 2>&1 | grep -q '\"result\"'" 2>/dev/null; then
        echo -e "${GREEN}✓ $agent initialized successfully${NC}"
    else
        echo -e "${RED}✗ $agent failed to initialize${NC}"
        exit 1
    fi
done

echo ""
echo "================================================================================"
echo -e "${GREEN}All agents verified successfully!${NC}"
echo "================================================================================"
echo ""
echo "Note: ECHO agents use MCP protocol (stdin/stdout) and cannot run as"
echo "traditional background daemons. In a real deployment, agents would be:"
echo ""
echo "  1. Claude Desktop Integration: Each agent as MCP server in Claude Desktop"
echo "  2. Workflow Engine: Agents coordinate via workflows (not directly backgrounded)"
echo "  3. Message Bus: Agents communicate via Redis pub/sub (already tested)"
echo ""
echo "For Day 1 simulation, we'll use the workflow engine instead:"
echo ""
echo "  cd $ECHO_ROOT"
echo "  mix run scripts/day1_simulation.exs"
echo ""
