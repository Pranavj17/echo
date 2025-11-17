#!/usr/bin/env bash
#
# Send Agenda to All Agents via Redis
# Usage: ./send_agenda.sh "Your agenda here"
#

set -e

AGENDA="${1:-3x Revenue Growth Strategy}"
TIMESTAMP=$(date +%s)
MESSAGE_ID="msg_${TIMESTAMP}"

echo "📢 Broadcasting Agenda to All Agents..."
echo "Subject: $AGENDA"
echo ""

# Publish directly to Redis messages:all channel
redis-cli -h localhost -p 6383 PUBLISH "messages:all" "{
  \"id\": \"$MESSAGE_ID\",
  \"from_role\": \"ceo\",
  \"to_role\": \"all\",
  \"type\": \"request\",
  \"subject\": \"STRATEGIC INITIATIVE: $AGENDA\",
  \"content\": {
    \"agenda\": \"$AGENDA\",
    \"budget\": 2000000,
    \"timeline\": \"18 months\",
    \"priority\": \"high\"
  },
  \"inserted_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")\"
}" > /dev/null

echo "✅ Agenda broadcast complete!"
echo ""
echo "📊 Monitor: http://localhost:4000"
echo "📝 Logs: tail -f logs/autonomous/*.log"
echo ""
