import Config

# Shared database configuration (from EchoShared)
config :echo_shared, EchoShared.Repo,
  database: "echo_org",
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5432"))

config :echo_shared,
  esenior_developer_repos: [EchoShared.Repo]

# SENIOR_DEVELOPER-specific configuration
config :senior_developer,
  role: :senior_developer,
  decision_authority: [
    :technology_strategy,
    :infrastructure_architecture,
    :engineering_budget,
    :team_structure,
    :technical_standards
  ],
  escalation_threshold: 0.7,
  autonomous_budget_limit: 500_000

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment-specific config
import_config "#{config_env()}.exs"
