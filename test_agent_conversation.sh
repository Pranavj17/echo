#!/bin/bash

set -e

echo "=========================================="
echo "ECHO Agent Communication Test"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DB_CMD="PGPASSWORD=postgres psql -U postgres -h localhost -p 5433 -d echo_org -t -c"

echo "Step 1: Send test message to Senior Developer"
echo "----------------------------------------------"
./send_message.sh senior_developer request what_do_you_do '{"question": "What do you do as a Senior Developer?"}'
echo ""
echo "${YELLOW}Waiting 15 seconds for LLM processing (deepseek-coder:6.7b)...${NC}"
sleep 15
echo ""

echo "Step 2: Check Redis pub/sub delivery"
echo "--------------------------------------"
SUBSCRIBERS=$(redis-cli -p 6383 PUBSUB NUMSUB messages:senior_developer | awk '{print $2}')
if [ "$SUBSCRIBERS" -gt 0 ]; then
    echo "${GREEN}✓ Senior Developer is subscribed to Redis (${SUBSCRIBERS} subscriber)${NC}"
else
    echo "${RED}✗ Senior Developer NOT subscribed to Redis${NC}"
fi
echo ""

echo "Step 3: Check PostgreSQL message storage"
echo "------------------------------------------"
MSG_COUNT=$($DB_CMD "SELECT COUNT(*) FROM messages WHERE to_role='senior_developer' AND subject='what_do_you_do'")
echo "Messages in DB: $MSG_COUNT"
if [ "$MSG_COUNT" -gt 0 ]; then
    echo "${GREEN}✓ Message stored in PostgreSQL${NC}"
    echo ""
    echo "Last message details:"
    $DB_CMD "SELECT from_role, to_role, subject, inserted_at FROM messages WHERE to_role='senior_developer' ORDER BY inserted_at DESC LIMIT 1"
else
    echo "${RED}✗ No messages found in PostgreSQL${NC}"
fi
echo ""

echo "Step 4: Check if Senior Developer sent response"
echo "------------------------------------------------"
RESPONSE_COUNT=$($DB_CMD "SELECT COUNT(*) FROM messages WHERE from_role='senior_developer' AND content->>'from_llm'='true' AND inserted_at > NOW() - INTERVAL '2 minutes'")
echo "LLM responses from Senior Developer: $RESPONSE_COUNT"
if [ "$RESPONSE_COUNT" -gt 0 ]; then
    echo "${GREEN}✓ Senior Developer responded with LLM${NC}"
    echo ""
    echo "Response preview:"
    $DB_CMD "SELECT substring(content->>'response', 1, 200) || '...' as response FROM messages WHERE from_role='senior_developer' AND content->>'from_llm'='true' ORDER BY inserted_at DESC LIMIT 1"
else
    echo "${YELLOW}⚠ No LLM response found yet${NC}"
fi
echo ""

echo "Step 5: Senior Developer asks Product Manager about login system"
echo "-----------------------------------------------------------------"
./send_message.sh product_manager request design_login_system '{
  "from": "senior_developer",
  "feature": "User login system",
  "requirements": "JWT authentication, OAuth2 support, password reset flow",
  "question": "What are the product requirements and priority for the login system?",
  "blocking": true
}'
echo ""
echo "${YELLOW}Waiting 15 seconds for Product Manager LLM response (llama3.1:8b)...${NC}"
sleep 15
echo ""

echo "Step 6: Check Product Manager received message"
echo "----------------------------------------------"
PM_MSG_COUNT=$($DB_CMD "SELECT COUNT(*) FROM messages WHERE to_role='product_manager' AND subject='design_login_system'")
echo "Messages to Product Manager: $PM_MSG_COUNT"
if [ "$PM_MSG_COUNT" -gt 0 ]; then
    echo "${GREEN}✓ Product Manager received message${NC}"
else
    echo "${RED}✗ Product Manager did not receive message${NC}"
fi
echo ""

echo "Step 7: Check if Product Manager responded"
echo "-------------------------------------------"
PM_RESPONSE_COUNT=$($DB_CMD "SELECT COUNT(*) FROM messages WHERE from_role='product_manager' AND content->>'from_llm'='true' AND inserted_at > NOW() - INTERVAL '2 minutes'")
echo "LLM responses from Product Manager: $PM_RESPONSE_COUNT"
if [ "$PM_RESPONSE_COUNT" -gt 0 ]; then
    echo "${GREEN}✓ Product Manager responded with LLM${NC}"
    echo ""
    echo "Response preview:"
    $DB_CMD "SELECT substring(content->>'response', 1, 200) || '...' as response FROM messages WHERE from_role='product_manager' AND content->>'from_llm'='true' ORDER BY inserted_at DESC LIMIT 1"
    echo ""
    echo "Response to agent:"
    $DB_CMD "SELECT to_role FROM messages WHERE from_role='product_manager' AND content->>'from_llm'='true' ORDER BY inserted_at DESC LIMIT 1"
else
    echo "${YELLOW}⚠ No LLM response from Product Manager yet${NC}"
fi
echo ""

echo "Step 8: Check Redis message flow"
echo "---------------------------------"
echo "Recent Redis publishes:"
redis-cli -p 6383 --csv INFO stats | grep -E "total_commands_processed|pubsub"
echo ""

echo "Step 9: Summary - All Messages in Last 5 Minutes"
echo "-------------------------------------------------"
$DB_CMD "SELECT 
  from_role || ' → ' || to_role as conversation,
  subject,
  CASE WHEN content->>'from_llm' = 'true' THEN '🤖 LLM' ELSE '👤 User' END as source,
  inserted_at
FROM messages 
WHERE inserted_at > NOW() - INTERVAL '5 minutes'
ORDER BY inserted_at ASC"

echo ""
echo "=========================================="
echo "Test Complete!"
echo "=========================================="
