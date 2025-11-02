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
  ];

  shellHook = ''
    echo "ECHO - Executive Coordination & Hierarchical Organization"
    echo "========================================================"
    echo ""
    echo "Erlang:  $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)"
    echo "Elixir:  $(elixir --version | grep Elixir)"
    echo ""
    echo "Project Structure:"
    echo "  shared/        - Shared library (MCP protocol, schemas, message bus)"
    echo "  agents/ceo/    - CEO agent (Phase 2 complete)"
    echo "  agents/...     - Other agents (Phase 3+)"
    echo ""
    echo "Quick Start:"
    echo "  cd shared && mix deps.get && mix compile"
    echo "  cd agents/ceo && mix deps.get && mix compile && mix escript.build"
    echo ""
    echo "Database: PostgreSQL (ensure it's running on localhost:5432)"
    echo "Redis:    Redis (ensure it's running on localhost:6379)"
    echo ""
    echo "Current Status: Phase 2 Complete (CEO Agent Reference Implementation)"
    echo "Next: Phase 3 - Implement remaining 8 agents"
    echo ""
  '';
}
