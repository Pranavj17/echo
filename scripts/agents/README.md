# ECHO Agent LLM Testing Scripts

This directory contains testing scripts for verifying LLM integration with ECHO agents.

## Scripts

### `test_agent_llm.sh`

Test a single agent's LLM integration.

**Usage:**
```bash
./test_agent_llm.sh <agent_name>
```

**Examples:**
```bash
./test_agent_llm.sh ceo
./test_agent_llm.sh senior_architect
./test_agent_llm.sh uiux_engineer
```

**Available Agents:**
- `ceo` - Uses qwen2.5:14b
- `cto` - Uses deepseek-coder:33b
- `chro` - Uses llama3.1:8b
- `operations_head` - Uses mistral:7b
- `product_manager` - Uses llama3.1:8b
- `senior_architect` - Uses deepseek-coder:33b
- `uiux_engineer` - Uses llama3.2-vision:11b
- `senior_developer` - Uses deepseek-coder:6.7b
- `test_lead` - Uses codellama:13b

**What it checks:**
1. Ollama installation
2. Ollama service status
3. Model availability
4. Agent file structure
5. LLM configuration
6. Text generation capability

### `test_all_agents_llm.sh`

Test all 9 agents in sequence.

**Usage:**
```bash
./test_all_agents_llm.sh
```

**Output:**
- Progress for each agent
- Summary of pass/fail counts
- Log files in `/tmp/llm_test_<agent>.log` for failed tests

## Requirements

- Ollama installed and running
- All required models downloaded (run `../../setup_llms.sh` first)
- Elixir 1.18+ installed
- Agent files in `../../agents/` directory

## Troubleshooting

### "Model not installed"

Run the model download script:
```bash
cd ../..
./setup_llms.sh
```

### "Ollama service not running"

Start Ollama:
```bash
ollama serve
```

Or let the script auto-start it.

### "Timeout error"

Large models (33b parameters) may timeout on slower systems. This is expected and doesn't indicate a problem. The timeout in production is longer (30-120 seconds).

To test with a smaller model:
```bash
# Test senior_developer instead of senior_architect
./test_agent_llm.sh senior_developer  # Uses 6.7b model
```

### "Agent directory not found"

Ensure you're running from the project root or that the script can find the agents:
```bash
cd /path/to/echo
./scripts/agents/test_agent_llm.sh ceo
```

## Output Example

```
🧪 Testing Agent LLM Integration
==================================

Agent: ceo
Model: qwen2.5:14b

Step 1: Checking Ollama
✓ Ollama is installed

Step 2: Checking Ollama service
✓ Ollama service is running

Step 3: Checking model availability
✓ Model qwen2.5:14b is installed

Step 4: Checking agent files
✓ Agent directory exists
✓ Agent file exists
✓ Agent has ai_consult tool

Step 5: Testing LLM configuration

LLM Test Output:
---
Configured model: qwen2.5:14b
System prompt length: 138 chars
Ollama responding: 7 models available

Testing generation...
✓ Generation successful
Response: As the CEO...

Summary:
--------
✓ Ollama installed and running
✓ Model qwen2.5:14b is available
✓ Agent ceo has LLM integration
✓ Configuration is correct
✓ Can generate responses

🎉 Agent LLM integration is working!
```

## See Also

- `../../LLM_TESTING_SUCCESS.md` - Test results and integration details
- `../../OLLAMA_SETUP_COMPLETE.md` - Setup documentation
- `../../LLM_INTEGRATION_SUMMARY.md` - Architecture overview
- `../../shared/lib/echo_shared/llm/` - LLM client implementation
