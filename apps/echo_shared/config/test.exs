import Config

# Test configuration
config :echo_shared, EchoShared.Repo,
  database: "echo_org_test#{System.get_env("MIX_TEST_PARTITION")}",
  username: "echo_org",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Print only warnings and errors during test
config :logger, level: :warning
