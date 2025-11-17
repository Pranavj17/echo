#!/bin/bash
set -euo pipefail

# Test CEO agent's session_consult for LinkedIn marketing budget planning

echo "=================================================="
echo " CEO Agent - LinkedIn Marketing Budget Test"
echo "=================================================="
echo ""

# Test 1: Initial consultation about LinkedIn marketing budget
echo "Test 1: Asking CEO to analyze LinkedIn marketing budget needs..."
echo ""

cat <<'EOF' | ./apps/ceo/ceo 2>&1 | grep -A 1000 '"result":'
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test-client", "version": "1.0.0"}}}
{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "session_consult", "arguments": {"question": "As CEO, I need your strategic analysis on allocating budget for LinkedIn marketing in 2025. Our company is a B2B SaaS with 50 employees. What budget range would be appropriate, what KPIs should we track, and what marketing strategies should we prioritize?"}}}
EOF

echo ""
echo "=================================================="
echo " Test Complete"
echo "=================================================="
