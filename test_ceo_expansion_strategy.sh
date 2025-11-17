#!/bin/bash
set -euo pipefail

# Test CEO agent's session_consult for Asian market expansion strategy

echo "========================================================"
echo " CEO Agent - Asian Market Expansion Strategy Test"
echo "========================================================"
echo ""

# Test: Multi-turn conversation about market expansion
echo "Turn 1: Initial strategic analysis on Asian market expansion..."
echo ""

cat <<'EOF' | ./apps/ceo/ceo 2>&1 | grep -A 100 '"result":' | tail -50
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test-client", "version": "1.0.0"}}}
{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "session_consult", "arguments": {"question": "As CEO of ECHO, I'm considering expanding into Asian markets (specifically Japan and Singapore) in 2025. Our B2B SaaS currently serves North American clients. What are the key factors I should evaluate before making this strategic decision? Consider market readiness, localization needs, regulatory challenges, and competitive landscape."}}}
EOF

echo ""
echo "========================================================"
echo " Test Complete - Check response quality above"
echo "========================================================"
