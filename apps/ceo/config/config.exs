import Config

# Database configuration inherited from shared/config/
# No need to duplicate here

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
