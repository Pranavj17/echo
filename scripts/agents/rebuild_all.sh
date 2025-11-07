#!/bin/bash
# Complete clean rebuild of ECHO system
# Run this after ANY code changes to ensure fixes are applied

set -e

ECHO_DIR="/Users/pranav/Documents/echo"
cd "$ECHO_DIR"

echo "🧹 Cleaning all build artifacts..."

# Clean shared library
cd shared
rm -rf _build deps
echo "  ✓ Shared library cleaned"

# Clean all agents
for agent in ceo cto chro product_manager senior_architect operations_head senior_developer test_lead uiux_engineer; do
    if [ -d "../apps/$agent" ]; then
        cd "../apps/$agent"
        rm -rf _build deps
        echo "  ✓ $agent cleaned"
    fi
done

cd "$ECHO_DIR"
echo ""
echo "🔨 Rebuilding shared library..."
cd shared
mix deps.get > /dev/null 2>&1
mix compile 2>&1 | grep -E "Compiling.*echo_shared|Generated.*echo_shared|error"
echo "  ✓ Shared library built"

cd "$ECHO_DIR"
echo ""
echo "🔨 Rebuilding all agents..."

for agent in ceo cto chro product_manager senior_architect operations_head; do
    echo "  Building $agent..."
    cd "apps/$agent"
    mix deps.get > /dev/null 2>&1
    mix compile > /dev/null 2>&1
    mix escript.build > /dev/null 2>&1
    echo "    ✓ $agent built ($(stat -f "%Sm" -t "%H:%M:%S" $agent))"
    cd "$ECHO_DIR"
done

echo ""
echo "✅ Complete rebuild finished!"
echo ""
echo "Agent executables:"
ls -lh apps/ceo/ceo apps/cto/cto apps/chro/chro apps/product_manager/product_manager apps/senior_architect/senior_architect apps/operations_head/operations_head 2>/dev/null || echo "Some agents not found"
echo ""
echo "Now run: ./day2_training_v2.sh"
