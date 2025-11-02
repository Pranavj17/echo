import Config

# Configure Ecto repository
config :echo_shared, EchoShared.Repo,
  database: "echo_org",
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  pool_size: 10

# Configure Ecto
config :echo_shared, ecto_repos: [EchoShared.Repo]

# Configure logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :agent_role]

# Import environment specific config
import_config "#{config_env()}.exs"
