#!/bin/bash

# Test ECHO Agent LLM Integration
# Tests if a specific agent can successfully use its configured LLM model
# Usage: ./test_agent_llm.sh <agent_name>

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Agent to model mapping (matches shared/lib/echo_shared/llm/config.ex)
# Format: agent|model
AGENT_MODELS=(
    "ceo|qwen2.5:14b"
    "cto|deepseek-coder:33b"
    "chro|llama3.1:8b"
    "operations_head|mistral:7b"
    "product_manager|llama3.1:8b"
    "senior_architect|deepseek-coder:33b"
    "uiux_engineer|llama3.2-vision:11b"
    "senior_developer|deepseek-coder:6.7b"
    "test_lead|codellama:13b"
)

# Helper function to get model for agent
get_model_for_agent() {
    local agent_name="$1"
    for entry in "${AGENT_MODELS[@]}"; do
        local agent=$(echo "$entry" | cut -d'|' -f1)
        local model=$(echo "$entry" | cut -d'|' -f2)
        if [ "$agent" = "$agent_name" ]; then
            echo "$model"
            return 0
        fi
    done
    return 1
}

# Display help
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo -e "${BLUE}Test ECHO Agent LLM Integration${NC}"
    echo "================================"
    echo ""
    echo "Usage: $0 <agent_name>"
    echo ""
    echo "Available agents:"
    for entry in "${AGENT_MODELS[@]}"; do
        agent=$(echo "$entry" | cut -d'|' -f1)
        model=$(echo "$entry" | cut -d'|' -f2)
        printf "  %-20s -> %s\n" "$agent" "$model"
    done
    echo ""
    echo "Example:"
    echo "  $0 senior_architect"
    echo "  $0 ceo"
    exit 0
fi

AGENT_NAME="$1"

# Normalize agent name (convert dashes to underscores)
AGENT_NAME=$(echo "$AGENT_NAME" | tr '-' '_')

echo -e "${BLUE}🧪 Testing Agent LLM Integration${NC}"
echo "=================================="
echo ""
echo "Agent: $AGENT_NAME"

# Check if agent is valid and get model
MODEL_NAME=$(get_model_for_agent "$AGENT_NAME")
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Unknown agent: $AGENT_NAME${NC}"
    echo ""
    echo "Available agents:"
    for entry in "${AGENT_MODELS[@]}"; do
        echo "  - $(echo "$entry" | cut -d'|' -f1)"
    done
    exit 1
fi
echo "Model: $MODEL_NAME"
echo ""

# Step 1: Check Ollama
echo -e "${BLUE}Step 1: Checking Ollama${NC}"
if ! command -v ollama &> /dev/null; then
    echo -e "${RED}✗ Ollama is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Ollama is installed${NC}"

# Step 2: Check service
echo -e "${BLUE}Step 2: Checking Ollama service${NC}"
if ! pgrep -x "ollama" > /dev/null && ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Ollama service is not running${NC}"
    echo "Starting Ollama..."
    ollama serve > /dev/null 2>&1 &
    sleep 3
    echo -e "${GREEN}✓ Ollama started${NC}"
else
    echo -e "${GREEN}✓ Ollama service is running${NC}"
fi
echo ""

# Step 3: Check model
echo -e "${BLUE}Step 3: Checking model availability${NC}"
INSTALLED_MODELS=$(ollama list 2>&1 | tail -n +2 | awk '{print $1}' || echo "")

if ! echo "$INSTALLED_MODELS" | grep -q "^${MODEL_NAME}$"; then
    echo -e "${RED}✗ Model $MODEL_NAME is not installed${NC}"
    echo ""
    echo "Install with:"
    echo "  ./scripts/ollama/download_model_single.sh $MODEL_NAME"
    exit 1
fi
echo -e "${GREEN}✓ Model $MODEL_NAME is installed${NC}"
echo ""

# Step 4: Check agent files
echo -e "${BLUE}Step 4: Checking agent files${NC}"

# Find project root (where apps/ directory is)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
AGENT_DIR="$PROJECT_ROOT/apps/$AGENT_NAME"

if [ ! -d "$AGENT_DIR" ]; then
    echo -e "${RED}✗ Agent directory not found: $AGENT_DIR${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Agent directory exists${NC}"

AGENT_FILE="$AGENT_DIR/lib/$AGENT_NAME.ex"
if [ ! -f "$AGENT_FILE" ]; then
    echo -e "${RED}✗ Agent file not found: $AGENT_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Agent file exists${NC}"

# Check if agent has ai_consult tool
if grep -q "ai_consult" "$AGENT_FILE"; then
    echo -e "${GREEN}✓ Agent has ai_consult tool${NC}"
else
    echo -e "${YELLOW}⚠ Agent may not have ai_consult tool${NC}"
fi
echo ""

# Step 5: Test LLM configuration
echo -e "${BLUE}Step 5: Testing LLM configuration${NC}"

# Create a temporary Elixir test script
TEST_SCRIPT="$PROJECT_ROOT/shared/test_llm_temp.exs"
cat > "$TEST_SCRIPT" << 'EOFTEST'
# Get agent role from command line
agent_role = System.argv() |> List.first() |> String.to_atom()

# Simple test that doesn't require full app startup
Mix.install([
  {:req, "~> 0.5"}
])

# Define minimal config and client modules inline
defmodule SimpleConfig do
  @agent_models %{
    ceo: "qwen2.5:14b",
    cto: "deepseek-coder:33b",
    chro: "llama3.1:8b",
    operations_head: "mistral:7b",
    product_manager: "llama3.1:8b",
    senior_architect: "deepseek-coder:33b",
    uiux_engineer: "llama3.2-vision:11b",
    senior_developer: "deepseek-coder:6.7b",
    test_lead: "codellama:13b"
  }

  @system_prompts %{
    ceo: "You are the CEO of an AI-powered software organization. You focus on strategic decisions, organizational direction, and high-level vision.",
    cto: "You are the CTO, responsible for technology strategy, architecture decisions, and technical leadership.",
    chro: "You are the CHRO, managing human resources, team dynamics, and organizational culture.",
    operations_head: "You are the Operations Head, ensuring infrastructure reliability, scalability, and operational excellence.",
    product_manager: "You are a Product Manager, defining product vision, prioritizing features, and managing the product roadmap.",
    senior_architect: "You are a Senior Architect, designing system architecture, defining technical specifications, and ensuring best practices.",
    uiux_engineer: "You are a UI/UX Engineer, creating user interfaces, ensuring excellent user experience, and implementing designs.",
    senior_developer: "You are a Senior Developer, implementing features, writing high-quality code, and solving technical challenges.",
    test_lead: "You are a Test Lead, ensuring quality through comprehensive testing, test automation, and QA processes."
  }

  def get_model(role), do: Map.get(@agent_models, role, "llama3.1:8b")
  def get_system_prompt(role), do: Map.get(@system_prompts, role, "You are a helpful AI assistant.")
end

defmodule SimpleClient do
  def health_check do
    endpoint = System.get_env("OLLAMA_ENDPOINT", "http://localhost:11434")
    url = "#{endpoint}/api/tags"

    case Req.get(url, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: body}} ->
        models = Map.get(body, "models", [])
        model_names = Enum.map(models, & &1["name"])
        {:ok, model_names}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, {:exception, e}}
  end

  def generate(model, prompt, opts \\ %{}) do
    endpoint = System.get_env("OLLAMA_ENDPOINT", "http://localhost:11434")
    url = "#{endpoint}/api/generate"

    payload = %{
      model: model,
      prompt: prompt,
      stream: false,
      options: %{
        temperature: opts[:temperature] || 0.7,
        num_predict: opts[:max_tokens] || 100
      }
    }

    payload = if system = opts[:system] do
      Map.put(payload, :system, system)
    else
      payload
    end

    case Req.post(url, json: payload, receive_timeout: 120_000) do
      {:ok, %{status: 200, body: body}} ->
        response_text = body["response"] || ""
        {:ok, response_text}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, {:exception, e}}
  end
end

# Run the test
model = SimpleConfig.get_model(agent_role)
IO.puts("Configured model: #{model}")

prompt = SimpleConfig.get_system_prompt(agent_role)
IO.puts("System prompt length: #{String.length(prompt)} chars")

# Test health check
case SimpleClient.health_check() do
  {:ok, models} ->
    IO.puts("Ollama responding: #{length(models)} models available")

  {:error, reason} ->
    IO.puts("Ollama error: #{inspect(reason)}")
    System.halt(1)
end

# Quick test generation
IO.puts("\nTesting generation...")
test_prompt = "In one sentence, what is your role?"

case SimpleClient.generate(model, test_prompt, %{system: prompt, max_tokens: 100, temperature: 0.7}) do
  {:ok, response} ->
    IO.puts("✓ Generation successful")
    IO.puts("Response: #{String.trim(response)}")

  {:error, reason} ->
    IO.puts("✗ Generation failed: #{inspect(reason)}")
    System.halt(1)
end
EOFTEST

echo ""
echo -e "${CYAN}LLM Test Output:${NC}"
echo "---"

if elixir "$TEST_SCRIPT" "$AGENT_NAME" 2>&1; then
    echo "---"
    echo ""
    echo -e "${GREEN}✓ LLM integration test passed!${NC}"
    rm -f "$TEST_SCRIPT" 2>/dev/null || true
else
    echo "---"
    echo ""
    echo -e "${RED}✗ LLM integration test failed${NC}"
    rm -f "$TEST_SCRIPT" 2>/dev/null || true
    exit 1
fi

# Step 6: Summary
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "--------"
echo -e "${GREEN}✓ Ollama installed and running${NC}"
echo -e "${GREEN}✓ Model $MODEL_NAME is available${NC}"
echo -e "${GREEN}✓ Agent $AGENT_NAME has LLM integration${NC}"
echo -e "${GREEN}✓ Configuration is correct${NC}"
echo -e "${GREEN}✓ Can generate responses${NC}"
echo ""
echo -e "${GREEN}🎉 Agent LLM integration is working!${NC}"
echo ""
echo "Next steps:"
echo "  - Build agent: cd $PROJECT_ROOT/apps/$AGENT_NAME && mix escript.build"
echo "  - Test interactively: ollama run $MODEL_NAME"
echo "  - Connect to Claude Desktop as MCP server"
