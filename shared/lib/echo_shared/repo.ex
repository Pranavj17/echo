defmodule EchoShared.Repo do
  @moduledoc """
  Ecto repository for ECHO shared database.

  All agents connect to the same PostgreSQL database to:
  - Store organizational decisions
  - Track inter-agent messages
  - Maintain shared memory
  - Record decision votes
  - Monitor agent health
  """

  use Ecto.Repo,
    otp_app: :echo_shared,
    adapter: Ecto.Adapters.Postgres
end
