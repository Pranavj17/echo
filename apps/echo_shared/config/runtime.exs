import Config

# Runtime configuration - evaluated when the application starts, not at compile time
# This is the recommended place for environment-specific configuration in Elixir 1.9+

# Configure database connection
# These values can be overridden by environment variables for different deployments
if config_env() != :test do
  config :echo_shared, EchoShared.Repo,
    database: System.get_env("DB_NAME", "echo_org"),
    username: System.get_env("DB_USER", "echo_org"),
    password: System.get_env("DB_PASSWORD", "postgres"),
    hostname: System.get_env("DB_HOST", "localhost"),
    port: String.to_integer(System.get_env("DB_PORT", "5433")),
    pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "1"))
end

# Configure Redis connection
# Port 6383 is used instead of standard 6379 to avoid conflicts with local Redis
# when using Docker (Docker maps container 6379 -> host 6383)
config :echo_shared, :redis,
  host: System.get_env("REDIS_HOST", "localhost"),
  port: String.to_integer(System.get_env("REDIS_PORT", "6383"))

# Configure Ollama (LLM) endpoint
config :echo_shared,
  ollama_endpoint: System.get_env("OLLAMA_ENDPOINT", "http://localhost:11434"),
  llm_enabled: System.get_env("LLM_ENABLED", "true") == "true"
