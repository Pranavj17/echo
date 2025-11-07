#!/bin/bash

# Check Ollama Installation and ECHO Models
# Verifies that Ollama is installed and shows which ECHO models are downloaded

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 ECHO Ollama Installation Check${NC}"
echo "=================================="
echo ""

# Step 1: Check if Ollama is installed
echo -e "${BLUE}Step 1: Checking Ollama installation...${NC}"
if command -v ollama &> /dev/null; then
    OLLAMA_VERSION=$(ollama --version 2>&1 || echo "unknown")
    echo -e "${GREEN}✓ Ollama is installed: ${OLLAMA_VERSION}${NC}"
else
    echo -e "${RED}✗ Ollama is NOT installed${NC}"
    echo ""
    echo "Install with: brew install ollama"
    echo "Or visit: https://ollama.com"
    exit 1
fi

echo ""

# Step 2: Check if Ollama service is running
echo -e "${BLUE}Step 2: Checking Ollama service...${NC}"
if pgrep -x "ollama" > /dev/null; then
    echo -e "${GREEN}✓ Ollama service is running${NC}"
    SERVICE_RUNNING=true
elif curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama service is running (API responding)${NC}"
    SERVICE_RUNNING=true
else
    echo -e "${YELLOW}⚠ Ollama service is NOT running${NC}"
    echo "  Start with: ollama serve"
    echo "  Or: ./scripts/ollama/start_ollama.sh"
    SERVICE_RUNNING=false
fi

echo ""

# Step 3: Check installed models
echo -e "${BLUE}Step 3: Checking installed models...${NC}"

if [ "$SERVICE_RUNNING" = false ]; then
    echo -e "${YELLOW}⚠ Cannot check models (service not running)${NC}"
    echo ""
    echo "Start Ollama and run this script again."
    exit 0
fi

# Get list of installed models
INSTALLED_MODELS=$(ollama list 2>&1 | tail -n +2 | awk '{print $1}' || echo "")

if [ -z "$INSTALLED_MODELS" ]; then
    echo -e "${YELLOW}⚠ No models installed${NC}"
    echo ""
    echo "Install all ECHO models with: ./setup_llms.sh"
    exit 0
fi

echo -e "${GREEN}Installed models:${NC}"
echo "$INSTALLED_MODELS"
echo ""

# Define ECHO models (model|agents)
ECHO_MODELS=(
    "qwen2.5:14b|CEO"
    "deepseek-coder:33b|CTO, Senior Architect"
    "llama3.1:8b|CHRO, Product Manager"
    "mistral:7b|Operations Head"
    "llama3.2-vision:11b|UI/UX Engineer"
    "deepseek-coder:6.7b|Senior Developer"
    "codellama:13b|Test Lead"
)

# Step 4: Check ECHO-specific models
echo -e "${BLUE}Step 4: Checking ECHO models...${NC}"
echo ""

MISSING_MODELS=()
PRESENT_MODELS=()

printf "%-30s %-20s %s\n" "Model" "Status" "Used By"
echo "--------------------------------------------------------------------------------"

for entry in "${ECHO_MODELS[@]}"; do
    model=$(echo "$entry" | cut -d'|' -f1)
    agents=$(echo "$entry" | cut -d'|' -f2)

    if echo "$INSTALLED_MODELS" | grep -q "^${model}"; then
        printf "%-30s ${GREEN}%-20s${NC} %s\n" "$model" "✓ Installed" "$agents"
        PRESENT_MODELS+=("$model")
    else
        printf "%-30s ${RED}%-20s${NC} %s\n" "$model" "✗ Missing" "$agents"
        MISSING_MODELS+=("$model")
    fi
done

echo ""

# Summary
TOTAL_MODELS=${#ECHO_MODELS[@]}
INSTALLED_COUNT=${#PRESENT_MODELS[@]}
MISSING_COUNT=${#MISSING_MODELS[@]}

echo -e "${BLUE}Summary:${NC}"
echo "--------"
echo "Total ECHO models: $TOTAL_MODELS"
echo -e "${GREEN}Installed: $INSTALLED_COUNT${NC}"

if [ $MISSING_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Missing: $MISSING_COUNT${NC}"
    echo ""
    echo -e "${YELLOW}Missing models:${NC}"
    for model in "${MISSING_MODELS[@]}"; do
        echo "  - $model"
    done
    echo ""
    echo "Download missing models with:"
    echo "  ./setup_llms.sh                                    # All models"
    echo "  ./scripts/ollama/download_models.sh                # Interactive"
    echo "  ./scripts/ollama/download_model_single.sh <model>  # Single model"
else
    echo -e "${GREEN}Missing: 0${NC}"
    echo ""
    echo -e "${GREEN}🎉 All ECHO models are installed!${NC}"
fi

echo ""

# Step 5: Disk usage
echo -e "${BLUE}Step 5: Disk usage${NC}"
if [ -d ~/.ollama/models ]; then
    DISK_USAGE=$(du -sh ~/.ollama/models 2>/dev/null | cut -f1)
    echo "Models directory size: $DISK_USAGE"
else
    echo "Models directory not found"
fi

echo ""
echo "=================================="
echo -e "${GREEN}Check complete!${NC}"
