import Config

# Development configuration
config :echo_shared, EchoShared.Repo,
  database: "echo_org_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
