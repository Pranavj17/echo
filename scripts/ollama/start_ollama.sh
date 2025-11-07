#!/bin/bash

# Start Ollama service in the background

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Ollama Service${NC}"
echo "=========================="
echo ""

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo -e "${RED}✗ Ollama is not installed${NC}"
    echo "Install with: brew install ollama"
    exit 1
fi

# Check if already running
if pgrep -x "ollama" > /dev/null; then
    echo -e "${YELLOW}⚠ Ollama is already running${NC}"
    echo ""
    echo "Process info:"
    ps aux | grep "[o]llama serve" || pgrep -x ollama | xargs ps -p
    echo ""
    echo "To restart, run: ./scripts/ollama/stop_ollama.sh && ./scripts/ollama/start_ollama.sh"
    exit 0
fi

# Check if port is in use
if lsof -i :11434 > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Port 11434 is already in use${NC}"
    echo ""
    echo "Processes using port 11434:"
    lsof -i :11434
    echo ""
    echo "Kill the process and try again."
    exit 1
fi

# Start Ollama
echo "Starting Ollama service..."
nohup ollama serve > ~/.ollama/ollama.log 2>&1 &
OLLAMA_PID=$!

sleep 3

# Verify it started
if pgrep -x "ollama" > /dev/null; then
    echo -e "${GREEN}✓ Ollama service started successfully${NC}"
    echo "PID: $OLLAMA_PID"
    echo "Endpoint: http://localhost:11434"
    echo "Log file: ~/.ollama/ollama.log"
    echo ""

    # Test the service
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Service is responding to API requests${NC}"
    else
        echo -e "${YELLOW}⚠ Service started but API not responding yet${NC}"
        echo "Wait a few seconds and check: curl http://localhost:11434/api/tags"
    fi

    echo ""
    echo "To stop: ./scripts/ollama/stop_ollama.sh"
    echo "To check status: pgrep -x ollama"

else
    echo -e "${RED}✗ Failed to start Ollama${NC}"
    echo ""
    echo "Check the log file: tail -f ~/.ollama/ollama.log"
    exit 1
fi
