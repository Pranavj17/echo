import Config

# Shared database configuration (from EchoShared)
config :echo_shared, EchoShared.Repo,
  database: "echo_org",
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5432"))

config :echo_shared,
  ecto_repos: [EchoShared.Repo]

# CEO-specific configuration
config :ceo,
  role: :ceo,
  decision_authority: [
    :strategic_planning,
    :budget_allocation,
    :c_suite_hiring,
    :company_direction,
    :crisis_management
  ],
  escalation_threshold: 0.7,
  autonomous_budget_limit: 1_000_000

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment-specific config
import_config "#{config_env()}.exs"
