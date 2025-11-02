import Config

# Runtime configuration (reads environment variables)

if config_env() == :prod do
  config :product_manager,
    autonomous_mode: System.get_env("PRODUCT_MANAGER_AUTONOMOUS_MODE", "true") == "true",
    autonomous_budget_limit: String.to_integer(System.get_env("PRODUCT_MANAGER_BUDGET_LIMIT", "500000")),
    escalation_threshold: String.to_float(System.get_env("PRODUCT_MANAGER_ESCALATION_THRESHOLD", "0.7"))
end
