import Config

# Development environment configuration
config :logger, level: :debug

# CTO development settings
config :cto,
  autonomous_mode: true,
  debug_decisions: true
