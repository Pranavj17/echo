#!/bin/bash

# Interactive ECHO Model Downloader
# Allows selective downloading of models for ECHO agents

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 ECHO Model Downloader${NC}"
echo "========================"
echo ""

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo -e "${RED}✗ Ollama is not installed${NC}"
    echo "Install with: brew install ollama"
    exit 1
fi

# Check if Ollama is running
if ! pgrep -x "ollama" > /dev/null && ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Ollama service is not running${NC}"
    echo "Starting Ollama..."
    ollama serve > /dev/null 2>&1 &
    sleep 3
    echo -e "${GREEN}✓ Ollama started${NC}"
    echo ""
fi

# Define models with metadata (model|size|agents|purpose)
MODEL_INFO=(
    "qwen2.5:14b|~9GB|CEO|Strategic reasoning & leadership"
    "deepseek-coder:33b|~19GB|CTO, Senior Architect|Technical architecture & code"
    "llama3.1:8b|~4.7GB|CHRO, Product Manager|People management & product strategy"
    "mistral:7b|~4.1GB|Operations Head|Operations & efficiency"
    "llama3.2-vision:11b|~7.9GB|UI/UX Engineer|Design & visual understanding"
    "deepseek-coder:6.7b|~3.8GB|Senior Developer|Code implementation"
    "codellama:13b|~7.3GB|Test Lead|Test generation & QA"
)

# Get installed models
INSTALLED_MODELS=$(ollama list 2>&1 | tail -n +2 | awk '{print $1}' || echo "")

echo "Select models to download (one at a time or 'all'):"
echo ""

MODEL_LIST=()
IDX=1

# Display menu
echo -e "${CYAN}Available models:${NC}"
echo ""
printf "%3s  %-25s %-10s %-30s %s\n" "#" "Model" "Size" "Used By" "Status"
echo "-------------------------------------------------------------------------------------"

for entry in "${MODEL_INFO[@]}"; do
    model=$(echo "$entry" | cut -d'|' -f1)
    size=$(echo "$entry" | cut -d'|' -f2)
    agents=$(echo "$entry" | cut -d'|' -f3)
    purpose=$(echo "$entry" | cut -d'|' -f4)

    if echo "$INSTALLED_MODELS" | grep -q "^${model}"; then
        status="${GREEN}✓ Installed${NC}"
    else
        status="${YELLOW}Not installed${NC}"
    fi

    printf "%3s  %-25s %-10s %-30s %s\n" "$IDX" "$model" "$size" "$agents" "$(echo -e $status)"
    MODEL_LIST+=("$model")
    ((IDX++))
done

echo ""
echo "Options:"
echo "  [1-7]  - Download specific model"
echo "  [all]  - Download all models (~20GB total)"
echo "  [q]    - Quit"
echo ""

# Read user input
read -p "Enter your choice: " CHOICE

if [ "$CHOICE" = "q" ] || [ "$CHOICE" = "Q" ]; then
    echo "Cancelled."
    exit 0
fi

# Handle "all" option
if [ "$CHOICE" = "all" ] || [ "$CHOICE" = "ALL" ]; then
    echo ""
    echo -e "${YELLOW}This will download ALL ECHO models (~20GB total)${NC}"
    read -p "Continue? [y/N]: " CONFIRM

    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi

    echo ""
    echo -e "${BLUE}Downloading all models...${NC}"
    echo ""

    for entry in "${MODEL_INFO[@]}"; do
        model=$(echo "$entry" | cut -d'|' -f1)
        if echo "$INSTALLED_MODELS" | grep -q "^${model}"; then
            echo -e "${GREEN}✓ $model already installed, skipping${NC}"
        else
            echo -e "${YELLOW}Downloading $model...${NC}"
            ollama pull "$model"
            echo -e "${GREEN}✓ $model installed${NC}"
            echo ""
        fi
    done

    echo -e "${GREEN}🎉 All models downloaded!${NC}"
    exit 0
fi

# Handle single model selection
if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le 7 ]; then
    MODEL_INDEX=$((CHOICE - 1))
    MODEL_NAME="${MODEL_LIST[$MODEL_INDEX]}"

    if echo "$INSTALLED_MODELS" | grep -q "^${MODEL_NAME}"; then
        echo -e "${GREEN}✓ $MODEL_NAME is already installed${NC}"
        read -p "Re-download? [y/N]: " REDOWNLOAD

        if [ "$REDOWNLOAD" != "y" ] && [ "$REDOWNLOAD" != "Y" ]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    echo ""
    # Find the model info
    for entry in "${MODEL_INFO[@]}"; do
        if [ "$(echo "$entry" | cut -d'|' -f1)" = "$MODEL_NAME" ]; then
            size=$(echo "$entry" | cut -d'|' -f2)
            agents=$(echo "$entry" | cut -d'|' -f3)
            purpose=$(echo "$entry" | cut -d'|' -f4)
            break
        fi
    done

    echo -e "${BLUE}Downloading: $MODEL_NAME${NC}"
    echo "Size: $size"
    echo "Used by: $agents"
    echo "Purpose: $purpose"
    echo ""

    ollama pull "$MODEL_NAME"

    echo ""
    echo -e "${GREEN}✓ $MODEL_NAME installed successfully${NC}"
    echo ""
    echo "Test with: ./scripts/ollama/test_model.sh $MODEL_NAME \"Hello!\""

else
    echo -e "${RED}Invalid choice${NC}"
    exit 1
fi
