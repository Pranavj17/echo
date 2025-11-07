#!/bin/bash

# Stop Ollama service

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Stopping Ollama Service${NC}"
echo "=========================="
echo ""

# Check if Ollama is running
if ! pgrep -x "ollama" > /dev/null; then
    echo -e "${YELLOW}⚠ Ollama is not running${NC}"
    exit 0
fi

# Get process info
echo "Current Ollama processes:"
ps aux | grep "[o]llama" || pgrep -x ollama | xargs ps -p
echo ""

# Kill the process
echo "Stopping Ollama..."
pkill -x ollama

sleep 2

# Verify it stopped
if pgrep -x "ollama" > /dev/null; then
    echo -e "${YELLOW}⚠ Ollama did not stop gracefully, forcing...${NC}"
    pkill -9 -x ollama
    sleep 1

    if pgrep -x "ollama" > /dev/null; then
        echo -e "${RED}✗ Failed to stop Ollama${NC}"
        echo "Try manually: kill -9 \$(pgrep -x ollama)"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Ollama service stopped${NC}"
echo ""
echo "To start again: ./scripts/ollama/start_ollama.sh"
echo "Or: ollama serve &"
