#!/bin/bash
# Rebuild all ECHO agents with current OTP version
# This ensures no "corrupt atom table" errors from version mismatches

set -e

echo "================================================"
echo "ECHO Agent Rebuild Script"
echo "================================================"
echo ""
echo "Elixir/OTP versions:"
elixir --version
echo ""

# Rebuild shared library first
echo "Step 1/10: Rebuilding shared library..."
cd /Users/pranav/Documents/echo/apps/echo_shared
mix clean
mix compile
echo "✓ Shared library rebuilt"
echo ""

# Array of all agents
agents=(
  "ceo"
  "cto"
  "chro"
  "operations_head"
  "product_manager"
  "senior_architect"
  "senior_developer"
  "test_lead"
  "uiux_engineer"
)

step=2
total_steps=10

# Rebuild each agent
for agent in "${agents[@]}"; do
  echo "Step $step/$total_steps: Rebuilding $agent..."
  cd "/Users/pranav/Documents/echo/apps/$agent"
  mix clean
  mix deps.get > /dev/null 2>&1
  mix compile
  mix escript.build

  # Verify escript was created
  if [ -f "./$agent" ]; then
    size=$(ls -lh "./$agent" | awk '{print $5}')
    echo "✓ $agent escript created ($size)"
  else
    echo "✗ ERROR: $agent escript not created!"
    exit 1
  fi

  ((step++))
  echo ""
done

echo "================================================"
echo "All agents rebuilt successfully!"
echo "================================================"
echo ""
echo "Testing agents..."
echo ""

# Test each agent
for agent in "${agents[@]}"; do
  echo -n "Testing $agent... "
  cd "/Users/pranav/Documents/echo/apps/$agent"

  # Start agent, capture output, kill after 1 second
  output=$(timeout 1 "./$agent" 2>&1 || true)

  # Check for success indicators
  if echo "$output" | grep -q "Starting.*MCP server"; then
    echo "✓ OK"
  elif echo "$output" | grep -qi "corrupt"; then
    echo "✗ FAILED (corrupt atom table)"
    exit 1
  else
    echo "? Unknown (may need manual verification)"
  fi
done

echo ""
echo "================================================"
echo "Rebuild and verification complete!"
echo "================================================"
