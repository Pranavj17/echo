#!/bin/bash

# Send a message to an ECHO agent via Redis
# Usage: ./send_agent_message_fixed.sh <to_agent> <message_type> <subject> [json_content]

if [ $# -lt 3 ]; then
    echo "Usage: $0 <to_agent> <message_type> <subject> [json_content]"
    echo ""
    echo "Examples:"
    echo "  $0 product_manager request test_message '{\"test\": \"hello\"}'"
    exit 1
fi

TO_AGENT="$1"
MSG_TYPE="$2"
SUBJECT="$3"
CONTENT_JSON="${4:-{}}"

# Generate message ID
MSG_ID="msg_$(date +%s)_$(( RANDOM % 10000 ))"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Create valid JSON using jq
MESSAGE=$(jq -n \
  --arg id "$MSG_ID" \
  --arg from "human" \
  --arg to "$TO_AGENT" \
  --arg type "$MSG_TYPE" \
  --arg subject "$SUBJECT" \
  --argjson content "$CONTENT_JSON" \
  --arg timestamp "$TIMESTAMP" \
  '{
    id: $id,
    from: $from,
    to: $to,
    type: $type,
    subject: $subject,
    content: $content,
    timestamp: $timestamp
  }')

CHANNEL="messages:$TO_AGENT"

echo "Sending message to $TO_AGENT..."
echo "Channel: $CHANNEL"
echo "Message: $MESSAGE"
echo ""

# Publish to Redis on correct port
redis-cli -p 6383 PUBLISH "$CHANNEL" "$MESSAGE"

echo ""
echo "✓ Message sent!"
