import Config

# Database configuration inherited from shared/config/
# No need to duplicate here

# CHRO-specific configuration
config :chro,
  role: :chro,
  decision_authority: [
    :hiring,
    :performance_management,
    :hr_policy,
    :conflict_resolution,
    :team_culture
  ],
  escalation_threshold: 0.7,
  autonomous_budget_limit: 300_000

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment-specific config
import_config "#{config_env()}.exs"
