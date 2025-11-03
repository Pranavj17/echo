{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Erlang and Elixir
    erlang_27
    elixir_1_18

    # Database
    postgresql

    # Redis
    redis

    # Build tools
    git

    # LSP
    elixir-ls

    # Direnv (for automatic environment loading)
    direnv
  ];

  # Environment variables
  DB_HOST = "localhost";
  DB_USER = "postgres";
  DB_PASSWORD = "postgres";
  DB_PORT = "5432";
  DB_NAME = "echo_org";

  REDIS_HOST = "localhost";
  REDIS_PORT = "6379";

  AUTONOMOUS_BUDGET_LIMIT = "1000000";
  MIX_ENV = "dev";

  shellHook = ''
    echo "ECHO - Executive Coordination & Hierarchical Organization"
    echo "========================================================"
    echo ""
    echo "Erlang:  $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)"
    echo "Elixir:  $(elixir --version | grep Elixir)"
    echo ""
    echo "Environment:"
    echo "  Database: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
    echo "  Redis:    $REDIS_HOST:$REDIS_PORT"
    echo "  Mix Env:  $MIX_ENV"
    echo ""
    echo "Project Structure:"
    echo "  shared/        - Shared library (MCP protocol, schemas, message bus)"
    echo "  agents/ceo/    - CEO agent"
    echo "  agents/cto/    - CTO agent"
    echo "  agents/chro/   - CHRO agent"
    echo "  agents/...     - Other agents (9 total)"
    echo ""
    echo "Quick Start:"
    echo "  cd shared && mix deps.get && mix compile"
    echo "  cd agents/ceo && mix deps.get && mix compile && mix escript.build"
    echo ""
    echo "Database: PostgreSQL (ensure it's running on localhost:5432)"
    echo "Redis:    Redis (ensure it's running on localhost:6379)"
    echo ""
    echo "Current Status: Phase 4 - Workflows & Integration"
    echo ""

    # Load .env file if it exists
    if [ -f .env ]; then
      echo "Loading additional environment variables from .env"
      set -a
      source .env
      set +a
    fi
  '';
}
