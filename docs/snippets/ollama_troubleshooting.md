# Ollama / LLM Troubleshooting

Common Ollama and LLM troubleshooting steps for ECHO.

## Ollama Not Running

**Symptom:** `Connection refused` or `Failed to get response from Ollama`

**Solution:**
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# If not running (Docker):
docker ps | grep ollama
docker start ollama

# If not running (systemd):
systemctl status ollama
systemctl start ollama
```

## Model Not Found

**Symptom:** `Error: model qwen2.5:14b not found`

**Solution:**
```bash
# List installed models
ollama list

# Pull missing model
ollama pull qwen2.5:14b

# Or install all ECHO models
./setup_llms.sh
```

## Slow Responses / Timeouts

**Symptom:** LLM queries take >60 seconds or timeout

**Possible Causes:**
- CPU bottleneck (other processes using CPU)
- Memory pressure (not enough RAM for model)
- Model too large for hardware

**Solutions:**
```bash
# Check system resources
top  # Linux
Activity Monitor  # macOS

# Use smaller model (if applicable)
export CEO_MODEL=qwen2.5:7b  # Instead of 14b

# Increase timeout
export LLM_TIMEOUT=300  # 5 minutes

# Restart Ollama
docker restart ollama  # If using Docker
```

## Model Inference Errors

**Symptom:** `(RuntimeError) model inference failed`

**Debug:**
```bash
# Test Ollama directly
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:14b",
  "prompt": "Hello, world!",
  "stream": false
}'

# Check Ollama logs
docker logs ollama  # If using Docker
journalctl -u ollama -f  # If using systemd
```

## Out of Memory

**Symptom:** `Out of memory` or Ollama crashes

**Solution:**
```bash
# Check available memory
free -h  # Linux
vm_stat  # macOS

# Unload unused models
ollama unload qwen2.5:14b

# Use smaller models
# See benchmark_models/claude.md for model comparison
```

## GPU Issues

**Symptom:** `CUDA error` or `GPU not found`

**Solution:**
```bash
# Check GPU availability
nvidia-smi  # NVIDIA GPUs

# Verify Ollama GPU support
docker run --gpus all ollama/ollama:latest nvidia-smi

# Force CPU mode (if GPU unavailable)
export OLLAMA_GPU=false
```

**Used in:**
- CLAUDE.md (troubleshooting section)
- apps/claude.md (agent development)
- scripts/claude.md (LocalCode troubleshooting)
- benchmark_models/claude.md
