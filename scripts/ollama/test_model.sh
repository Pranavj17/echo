#!/bin/bash

# Test a specific Ollama model with a custom prompt
# Usage: ./test_model.sh <model_name> [prompt]

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No model specified${NC}"
    echo ""
    echo "Usage: $0 <model_name> [prompt]"
    echo ""
    echo "Examples:"
    echo "  $0 llama3.1:8b"
    echo "  $0 llama3.1:8b \"Explain Elixir in one sentence\""
    echo "  $0 deepseek-coder:33b \"Write a hello world in Elixir\""
    echo ""
    exit 1
fi

MODEL_NAME="$1"
PROMPT="${2:-What is your purpose and what are you good at? Answer in 2-3 sentences.}"

echo -e "${BLUE}🧪 Testing Model: $MODEL_NAME${NC}"
echo "========================================"
echo ""

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo -e "${RED}✗ Ollama is not installed${NC}"
    exit 1
fi

# Check if Ollama is running
if ! pgrep -x "ollama" > /dev/null && ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Ollama service is not running${NC}"
    echo "Starting Ollama..."
    ./scripts/ollama/start_ollama.sh
    echo ""
fi

# Check if model is installed
INSTALLED_MODELS=$(ollama list 2>&1 | tail -n +2 | awk '{print $1}' || echo "")

if ! echo "$INSTALLED_MODELS" | grep -q "^${MODEL_NAME}$"; then
    echo -e "${RED}✗ Model $MODEL_NAME is not installed${NC}"
    echo ""
    echo "Install with:"
    echo "  ollama pull $MODEL_NAME"
    echo "  ./scripts/ollama/download_model_single.sh $MODEL_NAME"
    echo ""
    echo "Or see available models:"
    echo "  ./scripts/ollama/check_installation.sh"
    exit 1
fi

echo -e "${GREEN}✓ Model found: $MODEL_NAME${NC}"
echo ""

# Show model info
echo -e "${CYAN}Model info:${NC}"
ollama list | head -1
ollama list | grep "$MODEL_NAME"
echo ""

# Display the prompt
echo -e "${CYAN}Prompt:${NC}"
echo "\"$PROMPT\""
echo ""

# Test the model
echo -e "${CYAN}Response:${NC}"
echo "---"

START_TIME=$(date +%s%N)

RESPONSE=$(ollama run "$MODEL_NAME" "$PROMPT" 2>&1)
EXIT_CODE=$?

END_TIME=$(date +%s%N)
DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))
DURATION_S=$(echo "scale=2; $DURATION_MS / 1000" | bc)

echo "$RESPONSE"
echo "---"
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Test successful${NC}"
    echo "Response time: ${DURATION_S}s"
    echo "Response length: $(echo "$RESPONSE" | wc -c | tr -d ' ') characters"
    echo ""

    # Offer to run another test
    echo "Run another test? (y/N)"
    read -t 5 -n 1 CONTINUE || true
    echo ""

    if [ "$CONTINUE" = "y" ] || [ "$CONTINUE" = "Y" ]; then
        echo -e "${BLUE}Enter your prompt:${NC}"
        read -r NEW_PROMPT
        echo ""
        exec "$0" "$MODEL_NAME" "$NEW_PROMPT"
    fi

else
    echo -e "${RED}✗ Test failed${NC}"
    echo "Exit code: $EXIT_CODE"
    exit 1
fi
