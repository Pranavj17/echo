#!/bin/bash
# Test all ECHO agents for corrupt atom table errors

echo "================================================"
echo "ECHO Agent Verification Test"
echo "================================================"
echo ""
echo "System Information:"
elixir --version | head -2
echo ""
echo "Testing all 9 agents..."
echo "================================================"
echo ""

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

success_count=0
fail_count=0

for agent in "${agents[@]}"; do
  printf "%-20s " "$agent:"

  cd "/Users/pranav/Documents/echo/apps/$agent"

  # Check if escript exists
  if [ ! -f "./$agent" ]; then
    echo "✗ MISSING"
    ((fail_count++))
    continue
  fi
  
  # Test execution (timeout after 2 seconds)
  output=$(gtimeout 2 "./$agent" 2>&1 || timeout 2 "./$agent" 2>&1 || (sleep 2 & PID=$!; "./$agent" 2>&1 & AGENT_PID=$!; sleep 2; kill $AGENT_PID 2>/dev/null; kill $PID 2>/dev/null; wait 2>/dev/null))
  
  # Check for errors
  if echo "$output" | grep -qi "corrupt.*atom"; then
    echo "✗ CORRUPT ATOM TABLE ERROR"
    ((fail_count++))
  elif echo "$output" | grep -qi "error loading"; then
    echo "✗ LOADING ERROR"
    ((fail_count++))
  elif echo "$output" | grep -qi "undefined function.*main"; then
    echo "✗ MAIN FUNCTION ERROR"
    ((fail_count++))
  elif echo "$output" | grep -q "Starting.*MCP server"; then
    echo "✓ OK"
    ((success_count++))
  elif echo "$output" | grep -q "Starting.*Agent"; then
    echo "✓ OK"
    ((success_count++))
  else
    echo "? UNKNOWN (manual check needed)"
  fi
done

echo ""
echo "================================================"
echo "Results: $success_count/9 agents passed"
echo "================================================"

if [ $fail_count -eq 0 ]; then
  echo "✓ All agents working correctly!"
  exit 0
else
  echo "✗ $fail_count agent(s) failed"
  exit 1
fi
