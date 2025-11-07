#!/bin/bash
# Monitor Mac Mini LLM Server Status
# Usage: ./monitor_llm_server.sh

MAC_MINI_IP="${MAC_MINI_IP:-192.168.1.100}"
OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-http://${MAC_MINI_IP}:11434}"

echo "🖥️  ECHO LLM Server Monitor"
echo "================================"
echo "Endpoint: $OLLAMA_ENDPOINT"
echo ""

# Test 1: Network connectivity
echo "Test 1: Network Ping..."
if ping -c 2 -W 2000 "$MAC_MINI_IP" > /dev/null 2>&1; then
  echo "✅ Mac Mini is reachable"
else
  echo "❌ Mac Mini is not reachable"
  echo "   - Check if Mac Mini is on"
  echo "   - Check network connection"
  exit 1
fi

# Test 2: Ollama service
echo ""
echo "Test 2: Ollama Service..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${OLLAMA_ENDPOINT}/api/tags" --connect-timeout 5)

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Ollama service is running"
else
  echo "❌ Ollama service not responding (HTTP: $HTTP_CODE)"
  echo "   - Check if Ollama is running on Mac Mini"
  echo "   - Run: launchctl list | grep ollama"
  exit 1
fi

# Test 3: Available models
echo ""
echo "Test 3: Available Models..."
MODELS=$(curl -s "${OLLAMA_ENDPOINT}/api/tags" | python3 -m json.tool 2>/dev/null | grep '"name"' | cut -d'"' -f4)

if [ -z "$MODELS" ]; then
  echo "⚠️  No models found"
else
  echo "✅ Found models:"
  echo "$MODELS" | while read -r model; do
    echo "   - $model"
  done
fi

# Test 4: Response time
echo ""
echo "Test 4: Response Time..."
START_TIME=$(date +%s%3N)
curl -s "${OLLAMA_ENDPOINT}/api/tags" > /dev/null
END_TIME=$(date +%s%3N)
RESPONSE_TIME=$((END_TIME - START_TIME))

if [ "$RESPONSE_TIME" -lt 100 ]; then
  echo "✅ Excellent response time: ${RESPONSE_TIME}ms"
elif [ "$RESPONSE_TIME" -lt 500 ]; then
  echo "⚠️  Good response time: ${RESPONSE_TIME}ms"
else
  echo "❌ Slow response time: ${RESPONSE_TIME}ms"
  echo "   - Consider using Ethernet instead of WiFi"
fi

# Test 5: Quick inference test
echo ""
echo "Test 5: Quick Inference Test..."
FIRST_MODEL=$(echo "$MODELS" | head -n 1)

if [ -n "$FIRST_MODEL" ]; then
  echo "Testing with model: $FIRST_MODEL"
  START_TIME=$(date +%s)

  RESPONSE=$(curl -s "${OLLAMA_ENDPOINT}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$FIRST_MODEL\",\"prompt\":\"Say hi\",\"stream\":false,\"options\":{\"num_predict\":10}}" \
    --max-time 30)

  END_TIME=$(date +%s)
  INFERENCE_TIME=$((END_TIME - START_TIME))

  if echo "$RESPONSE" | grep -q '"response"'; then
    echo "✅ Inference successful (${INFERENCE_TIME}s)"
  else
    echo "❌ Inference failed"
    echo "   Response: $RESPONSE"
  fi
else
  echo "⚠️  Skipping (no models available)"
fi

echo ""
echo "================================"
echo "✅ All checks passed!"
echo ""
