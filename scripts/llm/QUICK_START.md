# LocalCode Quick Start

## 🚀 Simplest Way (Recommended)

### 1. Load Helper Functions

```bash
source ./scripts/llm/localcode_quick.sh
```

Output:
```
LocalCode helper functions loaded:
  lc_start [path]       - Start new session
  lc_query "question"   - Query current session
  lc_interactive        - Interactive mode
  lc_end                - End current session
  lc_list               - List all sessions
  lc_show               - Show current session
```

### 2. Start Session

```bash
lc_start

# Or specify directory:
lc_start /path/to/project
```

Output:
```
✓ Session started: session_20251111_010500_68694
  Use: lc_query "your question"
```

### 3. Query the LLM

```bash
lc_query "What is the ECHO project?"
```

Or interactive mode:
```bash
lc_interactive

localcode> explain echo architecture
[LLM responds]

localcode> how do agents communicate?
[LLM responds]

localcode> exit
```

### 4. End Session (Optional)

```bash
lc_end
```

---

## ⚙️ Configuration

### Timeout (For Slow Responses)

```bash
# Default is already 180 seconds (3 minutes)
# Increase further if needed:
export LLM_TIMEOUT=300  # 5 minutes

lc_query "complex question"
```

### Different Model

```bash
export LLM_MODEL="llama3.1:8b"          # Faster
# or
export LLM_MODEL="deepseek-coder:33b"   # More powerful
# or
export LLM_MODEL="qwen2.5:14b"          # Best reasoning

lc_query "your question"
```

---

## 📋 Complete Example Session

```bash
cd /Users/pranav/Documents/echo

# Load helpers
source ./scripts/llm/localcode_quick.sh

# Start session
lc_start

# Quick query
lc_query "What is ECHO?"

# Interactive exploration
lc_interactive
> How do agents make decisions?
> What's in the CEO agent code?
> Show me the message bus implementation
> exit

# End session
lc_end
```

---

## 🐛 Troubleshooting

### "Failed to get response"

**Problem:** Timeout or Ollama not responding

**Solution 1:** Increase timeout (default is already 3 minutes)
```bash
export LLM_TIMEOUT=300  # 5 minutes for very complex queries
lc_query "your question"
```

**Solution 2:** Check Ollama
```bash
curl http://localhost:11434/api/tags
# Should show list of models

ollama list
# Should show deepseek-coder:6.7b
```

**Solution 3:** Use smaller model
```bash
export LLM_MODEL="deepseek-coder:1.3b"  # Much faster
lc_query "your question"
```

### "No active session"

```bash
# Check if session exists
echo $LOCALCODE_SESSION

# Start new one
lc_start
```

### Context too large

**Problem:** "Context size: 15000 bytes (~3750 tokens)"

**Solution:** Edit startup context to be shorter
```bash
# Reduce CLAUDE.md lines loaded
vim ./scripts/llm/localcode_session.sh
# Change: head -200 CLAUDE.md → head -100 CLAUDE.md
```

---

## 💡 Tips

### 1. Keep Session Open All Day

```bash
# Morning
source ./scripts/llm/localcode_quick.sh
lc_start

# Query as needed throughout the day
lc_query "question 1"
lc_query "question 2"
...

# Evening
lc_end
```

### 2. Multiple Projects

```bash
# Project A
lc_start /path/to/projectA
lc_query "what's the architecture?"
lc_end

# Project B
lc_start /path/to/projectB
lc_query "what's the architecture?"
lc_end
```

### 3. Quick Commands in .bashrc / .zshrc

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias lc='source ~/Documents/echo/scripts/llm/localcode_quick.sh'
alias lcq='lc_query'
alias lci='lc_interactive'
```

Then:
```bash
lc          # Load functions
lc_start    # Start session
lcq "question"  # Quick query
lci         # Interactive mode
```

---

## 📊 Performance Tips

### Fast Queries (<5s)

```bash
export LLM_MODEL="deepseek-coder:1.3b"  # Smallest, fastest
lc_query "simple question"
```

### Balanced (5-10s)

```bash
export LLM_MODEL="deepseek-coder:6.7b"  # Default, good balance
lc_query "moderate question"
```

### Best Quality (10-30s)

```bash
export LLM_MODEL="qwen2.5:14b"  # Larger, smarter
lc_query "complex architectural question"
```

---

## 🎯 Common Use Cases

### Code Review
```bash
lc_query "Review apps/echo_shared/lib/echo_shared/message_bus.ex for security issues"
```

### Debugging
```bash
lc_query "I'm getting 'connection refused' to Redis. What could be wrong?"
```

### Learning Codebase
```bash
lc_interactive
> What agents exist in ECHO?
> How does the CEO agent work?
> Explain the decision-making flow
> exit
```

### Architecture Questions
```bash
lc_query "What are the pros and cons of the dual-write pattern in MessageBus?"
```

---

That's it! **Much simpler than the manual way.**
