import Config

# Runtime configuration (reads environment variables)

if config_env() == :prod do
  config :ceo,
    autonomous_mode: System.get_env("CEO_AUTONOMOUS_MODE", "true") == "true",
    autonomous_budget_limit: String.to_integer(System.get_env("CEO_BUDGET_LIMIT", "1000000")),
    escalation_threshold: String.to_float(System.get_env("CEO_ESCALATION_THRESHOLD", "0.7"))
end
