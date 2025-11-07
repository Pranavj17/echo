#!/bin/bash

# ECHO - Build All Agents
#
# This script rebuilds all 9 ECHO agent escripts.
# Run this after making code changes to any agent.
#
# Usage:
#   ./scripts/build_all_agents.sh

set -e

ECHO_ROOT="/Users/pranav/Documents/echo"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================================================"
echo "ECHO - Building All Agents"
echo "================================================================================"
echo ""

# Agent list
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

cd "$ECHO_ROOT"

# First, rebuild shared library
echo -e "${YELLOW}⧗ Building shared library...${NC}"
cd apps/echo_shared
mix deps.get > /dev/null 2>&1
mix compile > /dev/null 2>&1
echo -e "${GREEN}✓ Shared library built${NC}"
echo ""

cd "$ECHO_ROOT"

# Now build each agent
for agent in "${AGENTS[@]}"; do
    echo -e "${YELLOW}⧗ Building $agent...${NC}"

    cd "apps/$agent"

    # Clean old caches to avoid corruption
    rm -rf _build deps > /dev/null 2>&1

    # Get fresh dependencies
    mix deps.get > /dev/null 2>&1

    # Build escript
    if mix escript.build 2>&1 | grep -q "Generated escript"; then
        echo -e "${GREEN}✓ $agent built successfully${NC}"
    else
        echo -e "${RED}✗ $agent build failed${NC}"
        exit 1
    fi

    cd "$ECHO_ROOT"
    echo ""
done

echo "================================================================================"
echo -e "${GREEN}All 9 agents built successfully!${NC}"
echo "================================================================================"
echo ""
echo "Next steps:"
echo "  1. Start agents: ./scripts/run_day1_with_agents.sh"
echo "  2. Run orchestrator: cd shared && mix run ../scripts/orchestrate_real_agents.exs"
echo ""
