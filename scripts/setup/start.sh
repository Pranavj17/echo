#!/bin/bash

# ECHO - Master Startup Script
#
# This script does everything needed to start the ECHO system:
# 1. Checks prerequisites (PostgreSQL, Redis)
# 2. Builds all agents with latest code
# 3. Starts all 9 agents as background processes
# 4. Ready for orchestrator to run
#
# Usage:
#   ./start.sh

set -e

ECHO_ROOT="/Users/pranav/Documents/echo"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "================================================================================"
echo -e "${BLUE}ECHO - Complete System Startup${NC}"
echo "================================================================================"
echo ""

# Step 1: Check prerequisites
echo -e "${BLUE}Step 1/3: Checking Prerequisites${NC}"
echo "--------------------------------------------------------------------------------"

# Check PostgreSQL
if ! pg_isready -h localhost >/dev/null 2>&1; then
    echo -e "${RED}✗ PostgreSQL is not running${NC}"
    echo "  Start it: brew services start postgresql@14"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL is running${NC}"

# Check Redis
if ! redis-cli ping >/dev/null 2>&1; then
    echo -e "${RED}✗ Redis is not running${NC}"
    echo "  Start it: brew services start redis"
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

# Step 2: Build all agents
echo -e "${BLUE}Step 2/3: Building All Agents${NC}"
echo "--------------------------------------------------------------------------------"

# Kill any existing agents first
if pgrep -f "apps/" > /dev/null 2>&1; then
    echo -e "${YELLOW}⧗ Stopping existing agents...${NC}"
    pkill -f "apps/" || true
    sleep 2
    echo -e "${GREEN}✓ Existing agents stopped${NC}"
fi

# Build agents
echo -e "${YELLOW}⧗ Building all 9 agents...${NC}"

cd "$ECHO_ROOT"

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

BUILD_FAILED=0

# First, rebuild shared library with new config
echo -e "${YELLOW}  ⧗ Rebuilding shared library...${NC}"
cd "$ECHO_ROOT/shared"
if mix deps.get > /dev/null 2>&1 && mix compile > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ shared library${NC}"
else
    echo -e "${RED}  ✗ shared library (build failed)${NC}"
    exit 1
fi

cd "$ECHO_ROOT"

# Now build each agent
for agent in "${AGENTS[@]}"; do
    cd "apps/$agent"

    # Clean corrupted caches, get deps, build
    if rm -rf _build deps > /dev/null 2>&1 && \
       mix deps.get > /dev/null 2>&1 && \
       mix escript.build > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ $agent${NC}"
    else
        echo -e "${RED}  ✗ $agent (build failed)${NC}"
        BUILD_FAILED=1
    fi

    cd "$ECHO_ROOT"
done

if [ $BUILD_FAILED -eq 1 ]; then
    echo ""
    echo -e "${RED}Some agents failed to build. Fix errors and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All 9 agents built successfully${NC}"
echo ""

# Step 3: Start all agents
echo -e "${BLUE}Step 3/3: Starting All Agents${NC}"
echo "--------------------------------------------------------------------------------"

./scripts/run_day1_with_agents.sh

# This script will keep running (agents are running)
# User will Ctrl+C to stop
