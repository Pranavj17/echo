#!/bin/bash
# Simple Autonomous Test - Uses existing working test pattern

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Simple Autonomous Multi-Agent Test${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

echo "Testing CEO agent with session_consult..."
cd apps/ceo && timeout 180 mix run /Users/pranav/Documents/echo/test_from_ceo.exs | grep -E "(SUCCESS|FAIL|Session|Turn|Tokens)"

echo ""
echo -e "${GREEN}✓ Test complete!${NC}"
