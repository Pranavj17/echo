ExUnit.start()

# Start the application (test.exs configures Sandbox pool)
{:ok, _} = Application.ensure_all_started(:echo_shared)

# Setup sandbox mode for database tests
Ecto.Adapters.SQL.Sandbox.mode(EchoShared.Repo, :manual)
