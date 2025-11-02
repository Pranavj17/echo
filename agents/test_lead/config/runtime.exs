import Config

# Runtime configuration (reads environment variables)

if config_env() == :prod do
  config :test_lead,
    autonomous_mode: System.get_env("TEST_LEAD_AUTONOMOUS_MODE", "true") == "true",
    autonomous_budget_limit: String.to_integer(System.get_env("TEST_LEAD_BUDGET_LIMIT", "500000")),
    escalation_threshold: String.to_float(System.get_env("TEST_LEAD_ESCALATION_THRESHOLD", "0.7"))
end
