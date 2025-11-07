#!/bin/bash

# Quick fix for agents with corrupted dependency caches

set -e

ECHO_ROOT="/Users/pranav/Documents/echo"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Fixing failed agents..."

# These were the ones that failed
FAILED_AGENTS=(
    "product_manager"
    "senior_architect"
    "uiux_engineer"
)

cd "$ECHO_ROOT"

for agent in "${FAILED_AGENTS[@]}"; do
    echo -e "${YELLOW}⧗ Fixing $agent...${NC}"

    cd "apps/$agent"

    # Clean and rebuild
    rm -rf _build deps
    mix deps.get > /dev/null 2>&1
    mix escript.build > /dev/null 2>&1

    echo -e "${GREEN}✓ $agent fixed${NC}"

    cd "$ECHO_ROOT"
done

echo ""
echo -e "${GREEN}All failed agents fixed!${NC}"
