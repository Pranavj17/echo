#!/bin/bash
# Test session persistence across separate Mix runs

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Testing PostgreSQL Session Persistence Fix${NC}"
echo ""

# Test 1: Create session
echo -e "${YELLOW}Test 1: Creating new session...${NC}"

RESULT1=$(cd apps/ceo && timeout 180 mix run -e '
alias EchoShared.LLM.DecisionHelper

case DecisionHelper.consult_session(:ceo, nil, "What is my role as CEO?") do
  {:ok, result} ->
    IO.puts("SUCCESS")
    IO.puts("SESSION_ID:#{result.session_id}")
    IO.puts("TURN:#{result.turn_count}")
    IO.puts("TOKENS:#{result.total_tokens}")
  {:error, reason} ->
    IO.puts("FAILED:#{inspect(reason)}")
    exit(1)
end
' 2>&1)

if echo "$RESULT1" | grep -q "SUCCESS"; then
    SESSION_ID=$(echo "$RESULT1" | grep "SESSION_ID:" | cut -d: -f2-)
    TURN1=$(echo "$RESULT1" | grep "TURN:" | cut -d: -f2-)
    TOKENS1=$(echo "$RESULT1" | grep "TOKENS:" | cut -d: -f2-)

    echo -e "${GREEN}✅ Session created${NC}"
    echo "   Session ID: $SESSION_ID"
    echo "   Turn: $TURN1"
    echo "   Tokens: $TOKENS1"
    echo ""
else
    echo -e "${RED}❌ Session creation failed${NC}"
    echo "$RESULT1"
    exit 1
fi

# Test 2: Continue session (separate Mix run)
echo -e "${YELLOW}Test 2: Continuing session in separate Mix run...${NC}"

RESULT2=$(cd apps/ceo && timeout 180 mix run -e "
alias EchoShared.LLM.DecisionHelper

case DecisionHelper.consult_session(:ceo, \"$SESSION_ID\", \"What are my top priorities?\") do
  {:ok, result} ->
    IO.puts(\"SUCCESS\")
    IO.puts(\"SESSION_ID:#{result.session_id}\")
    IO.puts(\"TURN:#{result.turn_count}\")
    IO.puts(\"TOKENS:#{result.total_tokens}\")
  {:error, reason} ->
    IO.puts(\"FAILED:#{inspect(reason)}\")
    exit(1)
end
" 2>&1)

if echo "$RESULT2" | grep -q "SUCCESS"; then
    TURN2=$(echo "$RESULT2" | grep "TURN:" | cut -d: -f2-)
    TOKENS2=$(echo "$RESULT2" | grep "TOKENS:" | cut -d: -f2-)

    echo -e "${GREEN}✅ Session continuation successful${NC}"
    echo "   Turn: $TURN2 (was $TURN1)"
    echo "   Tokens: $TOKENS2 (was $TOKENS1)"
    echo ""
else
    echo -e "${RED}❌ Session continuation failed${NC}"
    echo "$RESULT2"
    exit 1
fi

# Test 3: Verify turn count increased
if [ "$TURN2" -gt "$TURN1" ]; then
    echo -e "${GREEN}✅ Turn count increased correctly${NC}"
else
    echo -e "${RED}❌ Turn count did not increase${NC}"
    exit 1
fi

# Test 4: Verify tokens increased (context grew)
if [ "$TOKENS2" -gt "$TOKENS1" ]; then
    echo -e "${GREEN}✅ Token count increased (context preserved)${NC}"
else
    echo -e "${RED}❌ Token count did not increase${NC}"
    exit 1
fi

# Test 5: End session
echo ""
echo -e "${YELLOW}Test 3: Ending session...${NC}"

RESULT3=$(cd apps/ceo && timeout 60 mix run -e "
alias EchoShared.LLM.Session

case Session.end_session(\"$SESSION_ID\") do
  {:ok, _conversation} ->
    IO.puts(\"SESSION_ENDED\")
  {:error, reason} ->
    IO.puts(\"FAILED:#{inspect(reason)}\")
end
" 2>&1)

if echo "$RESULT3" | grep -q "SESSION_ENDED"; then
    echo -e "${GREEN}✅ Session ended successfully${NC}"
else
    echo -e "${RED}❌ Session end failed${NC}"
    echo "$RESULT3"
    exit 1
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All tests passed!${NC}"
echo -e "${GREEN}Session persistence is working correctly${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"

exit 0
