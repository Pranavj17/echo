import Config

# Development environment configuration
config :logger, level: :debug

# PRODUCT_MANAGER development settings
config :product_manager,
  autonomous_mode: true,
  debug_decisions: true
