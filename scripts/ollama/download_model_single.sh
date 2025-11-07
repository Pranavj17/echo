#!/bin/bash

# Download a single Ollama model with progress and verification
# Usage: ./download_model_single.sh <model_name>

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No model specified${NC}"
    echo ""
    echo "Usage: $0 <model_name>"
    echo ""
    echo "Examples:"
    echo "  $0 llama3.1:8b"
    echo "  $0 deepseek-coder:33b"
    echo "  $0 qwen2.5:14b"
    echo ""
    echo "ECHO models:"
    echo "  qwen2.5:14b           - CEO (~9GB)"
    echo "  deepseek-coder:33b    - CTO, Senior Architect (~19GB)"
    echo "  llama3.1:8b           - CHRO, Product Manager (~4.7GB)"
    echo "  mistral:7b            - Operations Head (~4.1GB)"
    echo "  llama3.2-vision:11b   - UI/UX Engineer (~7.9GB)"
    echo "  deepseek-coder:6.7b   - Senior Developer (~3.8GB)"
    echo "  codellama:13b         - Test Lead (~7.3GB)"
    exit 1
fi

MODEL_NAME="$1"

echo -e "${BLUE}📦 Downloading Model: $MODEL_NAME${NC}"
echo "=================================="
echo ""

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo -e "${RED}✗ Ollama is not installed${NC}"
    echo "Install with: brew install ollama"
    exit 1
fi

echo -e "${GREEN}✓ Ollama is installed${NC}"

# Check if Ollama is running
if ! pgrep -x "ollama" > /dev/null && ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Ollama service is not running${NC}"
    echo "Starting Ollama..."
    ollama serve > /dev/null 2>&1 &
    sleep 3
    echo -e "${GREEN}✓ Ollama started${NC}"
fi

echo ""

# Check if model is already installed
INSTALLED_MODELS=$(ollama list 2>&1 | tail -n +2 | awk '{print $1}' || echo "")

if echo "$INSTALLED_MODELS" | grep -q "^${MODEL_NAME}$"; then
    echo -e "${YELLOW}⚠ Model $MODEL_NAME is already installed${NC}"
    echo ""
    ollama list | grep "$MODEL_NAME" || true
    echo ""
    read -p "Re-download? [y/N]: " REDOWNLOAD

    if [ "$REDOWNLOAD" != "y" ] && [ "$REDOWNLOAD" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi

    echo ""
    echo -e "${BLUE}Re-downloading $MODEL_NAME...${NC}"
else
    echo -e "${BLUE}Downloading $MODEL_NAME for the first time...${NC}"
fi

echo ""
echo "This may take several minutes depending on model size and your connection."
echo ""

# Download the model
START_TIME=$(date +%s)

if ollama pull "$MODEL_NAME"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))

    echo ""
    echo -e "${GREEN}✓ Successfully downloaded $MODEL_NAME${NC}"
    echo "Time taken: ${MINUTES}m ${SECONDS}s"
    echo ""

    # Show model info
    echo -e "${BLUE}Model information:${NC}"
    ollama list | grep "$MODEL_NAME" || true
    echo ""

    # Test the model
    echo -e "${BLUE}Testing model...${NC}"
    TEST_RESPONSE=$(ollama run "$MODEL_NAME" "Say 'Hello from $MODEL_NAME' in one short sentence." 2>&1 | head -5)
    echo "Response: $TEST_RESPONSE"
    echo ""

    echo -e "${GREEN}🎉 Model ready to use!${NC}"
    echo ""
    echo "Next steps:"
    echo "  - Test interactively: ollama run $MODEL_NAME"
    echo "  - Test with script: ./scripts/ollama/test_model.sh $MODEL_NAME \"Your prompt\""
    echo "  - Check all models: ./scripts/ollama/check_installation.sh"

else
    echo ""
    echo -e "${RED}✗ Failed to download $MODEL_NAME${NC}"
    echo ""
    echo "Possible reasons:"
    echo "  - Invalid model name"
    echo "  - Network issues"
    echo "  - Insufficient disk space"
    echo ""
    echo "Check available models at: https://ollama.com/library"
    exit 1
fi
