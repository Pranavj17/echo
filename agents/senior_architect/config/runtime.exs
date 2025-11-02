import Config

# Runtime configuration (reads environment variables)

if config_env() == :prod do
  config :senior_architect,
    autonomous_mode: System.get_env("SENIOR_ARCHITECT_AUTONOMOUS_MODE", "true") == "true",
    autonomous_budget_limit: String.to_integer(System.get_env("SENIOR_ARCHITECT_BUDGET_LIMIT", "500000")),
    escalation_threshold: String.to_float(System.get_env("SENIOR_ARCHITECT_ESCALATION_THRESHOLD", "0.7"))
end
