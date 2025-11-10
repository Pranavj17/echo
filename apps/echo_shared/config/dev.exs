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

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
