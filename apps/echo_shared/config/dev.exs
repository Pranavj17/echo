import Config

# Development environment configuration
# These are STATIC values for local development

# Database configuration for development
config :echo_shared, EchoShared.Repo,
  database: "echo_org",
  username: "echo_org",
  password: "postgres",
  hostname: "localhost",
  port: 5433,  # Docker maps PostgreSQL 5432 -> 5433
  pool: DBConnection.ConnectionPool,  # Default pool for dev
  show_sensitive_data_on_connection_error: true

# Redis configuration for development
config :echo_shared, :redis,
  host: "localhost",
  port: 6383  # Docker maps Redis 6379 -> 6383

# Ollama (LLM) configuration for development
config :echo_shared,
  ollama_endpoint: "http://localhost:11434",
  llm_enabled: true

# LLM Session configuration (LocalCode-style conversation memory)
config :echo_shared, :llm_session,
  # Maximum conversation turns to keep in history
  max_turns: 5,
  # Session timeout (1 hour of inactivity)
  timeout_ms: 3_600_000,
  # Cleanup interval (15 minutes)
  cleanup_interval_ms: 900_000,
  # Context size warnings (in estimated tokens)
  warning_threshold: 4_000,
  limit_threshold: 6_000

# Agent-specific LLM models (can be overridden via environment variables)
# These match LocalCode-style integration with specialized models per role
config :echo_shared, :agent_models, %{
  # Leadership - Faster models for responsive decision-making
  ceo: "llama3.1:8b",                    # Strategic reasoning (FASTER: 14b → 8b)
  cto: "deepseek-coder:6.7b",            # Technical architecture (FASTER: 33b → 6.7b)
  chro: "llama3.1:8b",                   # People & culture
  operations_head: "mistral:7b",         # Operations efficiency
  product_manager: "llama3.1:8b",        # Product strategy

  # Technical - Code-focused models
  senior_architect: "deepseek-coder:6.7b",  # System design (FASTER: 33b → 6.7b)
  uiux_engineer: "llama3.1:8b",             # Design (FASTER: 11b vision → 8b)
  senior_developer: "deepseek-coder:6.7b",  # Code implementation
  test_lead: "deepseek-coder:6.7b"          # Testing (FASTER: 13b → 6.7b)
}

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
