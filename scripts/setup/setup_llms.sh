#!/bin/bash

# ECHO LLM Setup Script
# Installs Ollama and pulls all required models for ECHO agents

set -e

echo "🚀 ECHO Local LLM Setup"
echo "======================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "${YELLOW}Warning: This script is optimized for macOS. For Linux, install Ollama from https://ollama.com${NC}"
    echo ""
fi

# Step 1: Install Ollama
echo "${BLUE}Step 1: Installing Ollama...${NC}"
if command -v ollama &> /dev/null; then
    echo "${GREEN}✓ Ollama is already installed${NC}"
    ollama --version
else
    echo "Installing Ollama via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "${YELLOW}Homebrew not found. Please install from https://brew.sh${NC}"
        echo "Or install Ollama manually from https://ollama.com"
        exit 1
    fi
    brew install ollama
    echo "${GREEN}✓ Ollama installed successfully${NC}"
fi

echo ""

# Step 2: Start Ollama service
echo "${BLUE}Step 2: Starting Ollama service...${NC}"
if pgrep -x "ollama" > /dev/null; then
    echo "${GREEN}✓ Ollama service is already running${NC}"
else
    echo "Starting Ollama service in the background..."
    ollama serve > /dev/null 2>&1 &
    sleep 3
    echo "${GREEN}✓ Ollama service started${NC}"
fi

echo ""

# Step 3: Pull models for each agent
echo "${BLUE}Step 3: Pulling LLM models for ECHO agents...${NC}"
echo "This will download several GB of data and may take 15-30 minutes."
echo ""

# Define agent models (agent|model format)
AGENT_MODELS=(
    "CEO|qwen2.5:14b"
    "CTO|deepseek-coder:33b"
    "CHRO|llama3.1:8b"
    "Operations Head|mistral:7b"
    "Product Manager|llama3.1:8b"
    "Senior Architect|deepseek-coder:33b"
    "UI/UX Engineer|llama3.2-vision:11b"
    "Senior Developer|deepseek-coder:6.7b"
    "Test Lead|codellama:13b"
)

# Get unique models
UNIQUE_MODELS=$(for entry in "${AGENT_MODELS[@]}"; do echo "$entry" | cut -d'|' -f2; done | sort -u)

echo "Models to install:"
for model in $UNIQUE_MODELS; do
    echo "  - $model"
done
echo ""

# Pull each unique model
for model in $UNIQUE_MODELS; do
    echo "${YELLOW}Pulling $model...${NC}"
    if ollama list | grep -q "^${model}"; then
        echo "${GREEN}✓ $model already installed${NC}"
    else
        ollama pull "$model"
        echo "${GREEN}✓ $model installed successfully${NC}"
    fi
    echo ""
done

# Step 4: Verify installation
echo "${BLUE}Step 4: Verifying installation...${NC}"
echo ""

echo "Installed models:"
ollama list
echo ""

# Step 5: Test a model
echo "${BLUE}Step 5: Testing model...${NC}"
echo "Testing with llama3.1:8b..."
echo ""

TEST_RESPONSE=$(ollama run llama3.1:8b "Say 'ECHO LLM setup successful!' in one sentence." 2>&1 | head -1)
echo "Response: $TEST_RESPONSE"
echo ""

# Step 6: Display agent-model mapping
echo "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Agent-Model Mapping:"
echo "--------------------"
printf "%-20s %s\n" "Agent" "Model"
echo "--------------------"
for entry in "${AGENT_MODELS[@]}"; do
    agent=$(echo "$entry" | cut -d'|' -f1)
    model=$(echo "$entry" | cut -d'|' -f2)
    printf "%-20s %s\n" "$agent" "$model"
done
echo ""

# Step 7: Environment variables
echo "${BLUE}Optional Configuration:${NC}"
echo ""
echo "You can customize models per agent using environment variables:"
echo "  export CEO_MODEL=qwen2.5:14b"
echo "  export CTO_MODEL=deepseek-coder:33b"
echo ""
echo "To disable LLM for specific agents:"
echo "  export CEO_LLM_ENABLED=false"
echo ""
echo "To change Ollama endpoint:"
echo "  export OLLAMA_ENDPOINT=http://localhost:11434"
echo ""

# Step 8: Next steps
echo "${BLUE}Next Steps:${NC}"
echo "1. Compile the shared library: cd shared && mix deps.get && mix compile"
echo "2. Compile and run an agent: cd apps/ceo && mix deps.get && mix escript.build"
echo "3. Test AI consultation: Use the 'ai_consult' tool in any agent"
echo ""
echo "For more information, see CLAUDE.md"
echo ""
echo "${GREEN}Happy building with ECHO! 🎉${NC}"
