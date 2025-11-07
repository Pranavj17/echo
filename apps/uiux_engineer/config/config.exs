import Config

# Database configuration inherited from shared/config/
# No need to duplicate here

# UIUX_ENGINEER-specific configuration
config :uiux_engineer,
  role: :uiux_engineer,
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
