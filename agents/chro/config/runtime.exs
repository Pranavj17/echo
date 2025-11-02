import Config

# Runtime configuration (reads environment variables)

if config_env() == :prod do
  config :chro,
    autonomous_mode: System.get_env("CHRO_AUTONOMOUS_MODE", "true") == "true",
    autonomous_budget_limit: String.to_integer(System.get_env("CHRO_BUDGET_LIMIT", "500000")),
    escalation_threshold: String.to_float(System.get_env("CHRO_ESCALATION_THRESHOLD", "0.7"))
end
