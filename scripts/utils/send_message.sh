#!/bin/bash

# Send a message to an ECHO agent via Redis
# Usage: ./send_message.sh <to_agent> <message_type> <subject> [json_content]

if [ $# -lt 3 ]; then
    echo "Usage: $0 <to_agent> <message_type> <subject> [json_content]"
    echo "Example: $0 product_manager request test '{\"priority\": \"high\"}'"
    exit 1
fi

TO_AGENT="$1"
MSG_TYPE="$2"
SUBJECT="$3"
CONTENT_JSON="${4:-\{\}}"

# Generate message ID
MSG_ID="msg_$(date +%s)_$(( RANDOM % 10000 ))"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Create valid JSON using printf and proper escaping
MESSAGE=$(printf '{"id":"%s","from":"human","to":"%s","type":"%s","subject":"%s","content":%s,"timestamp":"%s"}' \
  "$MSG_ID" "$TO_AGENT" "$MSG_TYPE" "$SUBJECT" "$CONTENT_JSON" "$TIMESTAMP")

# Validate JSON
echo "$MESSAGE" | python3 -m json.tool > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Invalid JSON generated"
    echo "Message: $MESSAGE"
    exit 1
fi

CHANNEL="messages:$TO_AGENT"

echo "Sending message to $TO_AGENT..."
echo "Message: $(echo "$MESSAGE" | python3 -m json.tool 2>/dev/null || echo "$MESSAGE")"
echo ""

# Publish to Redis
RESULT=$(redis-cli -p 6383 PUBLISH "$CHANNEL" "$MESSAGE")

if [ "$RESULT" -gt 0 ]; then
    echo "✓ Message delivered to $RESULT subscriber(s)"
else
    echo "⚠ Warning: No subscribers listening on $CHANNEL"
fi
