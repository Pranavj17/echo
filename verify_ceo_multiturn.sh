#!/bin/bash
set -euo pipefail

echo "========================================="
echo " Multi-Turn CEO Session Verification"
echo "========================================="
echo ""

# Start the CEO agent in the background
echo "Starting CEO agent..."
./apps/ceo/ceo > /tmp/ceo_output.log 2>&1 &
CEO_PID=$!
echo "CEO agent running (PID: $CEO_PID)"
sleep 2

# Function to send MCP request
send_request() {
    local id=$1
    local method=$2
    local params=$3
    echo "{\"jsonrpc\": \"2.0\", \"id\": $id, \"method\": \"$method\", \"params\": $params}"
}

# Function to call tool
call_tool() {
    local id=$1
    local tool=$2
    local args=$3
    send_request "$id" "tools/call" "{\"name\": \"$tool\", \"arguments\": $args}"
}

echo ""
echo "Turn 1: Ask about hiring strategy..."
echo ""

# Initialize
send_request 1 "initialize" '{"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test-client", "version": "1.0.0"}}'

# First question (creates new session)
cat <<'EOF'
{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "session_consult", "arguments": {"question": "Should I hire 5 senior engineers or 10 junior engineers for our expansion?"}}}
EOF

sleep 25  # Wait for LLM response

echo ""
echo "Turn 2: Follow-up question (uses same session)..."
echo ""

# Get the session_id from the database
SESSION_ID=$(PGPASSWORD=postgres psql -h 127.0.0.1 -p 5433 -U echo_org -d echo_org -t -c "SELECT session_id FROM llm_sessions WHERE agent_role = 'ceo' ORDER BY created_at DESC LIMIT 1;" | xargs)

echo "Using session: $SESSION_ID"

# Second question (continues conversation)
cat <<EOF
{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "session_consult", "arguments": {"session_id": "$SESSION_ID", "question": "What about the budget implications of each option?"}}}
EOF

sleep 25  # Wait for LLM response

# Clean up
kill $CEO_PID 2>/dev/null || true

echo ""
echo "========================================="
echo "Verification Steps:"
echo "========================================="
echo ""
echo "1. Check the database for the session:"
echo "   PGPASSWORD=postgres psql -h 127.0.0.1 -p 5433 -U echo_org -d echo_org -c \"SELECT session_id, turn_count FROM llm_sessions WHERE session_id = '$SESSION_ID';\""
echo ""
echo "2. Verify turn_count increased from 1 to 2"
echo ""
echo "3. Check conversation history:"
echo "   PGPASSWORD=postgres psql -h 127.0.0.1 -p 5433 -U echo_org -d echo_org -c \"SELECT jsonb_array_length(conversation_history) FROM llm_sessions WHERE session_id = '$SESSION_ID';\""
echo ""
