import Config

# Runtime configuration (reads environment variables at startup)

# Database configuration - loaded at runtime for all environments
config :echo_shared, EchoShared.Repo,
  database: System.get_env("DB_NAME", "echo_org"),
  username: System.get_env("DB_USER", "echo_org"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5433")),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "1"))

# CTO-specific runtime configuration
if config_env() == :prod do
  config :cto,
    autonomous_mode: System.get_env("CTO_AUTONOMOUS_MODE", "true") == "true",
    autonomous_budget_limit: String.to_integer(System.get_env("CTO_BUDGET_LIMIT", "500000")),
    escalation_threshold: String.to_float(System.get_env("CTO_ESCALATION_THRESHOLD", "0.7"))
end
