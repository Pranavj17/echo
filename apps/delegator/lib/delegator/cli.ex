defmodule Delegator.CLI do
  @moduledoc """
  Command-line interface for the Delegator MCP Server.

  The delegator runs in stdio mode by default for Claude Desktop integration.

  ## Usage

      # Run as MCP server (stdio mode) - for Claude Desktop
      ./delegator

      # Show help
      ./delegator --help

      # Show version
      ./delegator --version

  ## Claude Desktop Configuration

  Add to your Claude Desktop config (~/Library/Application Support/Claude/claude_desktop_config.json):

      {
        "mcpServers": {
          "echo-delegator": {
            "command": "/absolute/path/to/echo/apps/delegator/delegator"
          }
        }
      }
  """

  require Logger

  def main(args) do
    case args do
      ["--help"] ->
        show_help()
        System.halt(0)

      ["--version"] ->
        show_version()
        System.halt(0)

      ["--info"] ->
        show_info()
        System.halt(0)

      [] ->
        # Default: Run as MCP server (stdio mode)
        run_mcp_server()

      other ->
        IO.puts("Unknown arguments: #{inspect(other)}")
        IO.puts("\nUse --help for usage information")
        System.halt(1)
    end
  end

  defp run_mcp_server do
    Logger.info("Starting Delegator MCP Server in stdio mode...")

    # Start the application
    {:ok, _} = Application.ensure_all_started(:delegator)

    # Start the MCP server loop (reads from stdin, writes to stdout)
    Delegator.start()
  end

  defp show_help do
    IO.puts("""
    Delegator MCP Server - Intelligent Agent Coordinator for ECHO

    USAGE:
        delegator              Run as MCP server (stdio mode) for Claude Desktop
        delegator --help       Show this help message
        delegator --version    Show version information
        delegator --info       Show delegator capabilities

    CLAUDE DESKTOP SETUP:

    Add this to your Claude Desktop config:
    ~/Library/Application Support/Claude/claude_desktop_config.json

        {
          "mcpServers": {
            "echo-delegator": {
              "command": "/absolute/path/to/echo/apps/delegator/delegator"
            }
          }
        }

    FEATURES:

    The Delegator solves ECHO's resource usage problem by spawning only
    the agents you need for a specific task, reducing CPU and memory usage
    by 70-85%.

    Available MCP Tools:
      - start_session         Start work session with agent category
      - list_active_agents    Show running agents
      - delegate_task         Assign tasks to active agents
      - spawn_agent           Add agent to session dynamically
      - shutdown_agent        Remove agent from session
      - session_status        View session details
      - end_session           Gracefully shutdown all agents

    Agent Categories:
      - strategic:    CEO, CTO, Product Manager
      - technical:    CTO, Senior Architect, Senior Developer
      - development:  Senior Developer, Test Lead
      - hr:           CEO, CHRO
      - operations:   Operations Head, CTO
      - product:      Product Manager, CEO, UI/UX Engineer
      - quick_fix:    Senior Developer only

    For more information, see: docs/architecture/DELEGATOR_ARCHITECTURE.md
    """)
  end

  defp show_version do
    IO.puts("""
    echo-delegator v0.1.0
    Intelligent agent coordinator - spawns only the agents you need

    Elixir: #{System.version()}
    OTP: #{System.otp_release()}
    """)
  end

  defp show_info do
    IO.puts("""
    Delegator MCP Server - Agent Coordinator

    STATUS: Phase 1 Implementation (Simple Interactive Delegator)

    CAPABILITIES:
      ✓ Session-based agent management
      ✓ Category-based agent selection (7 predefined categories)
      ✓ Dynamic agent spawning during session
      ✓ Hierarchical delegation (via CEO when active)
      ✓ Graceful agent lifecycle management
      ✓ Resource usage monitoring

    AGENT SETS:

      strategic (3 agents, ~55GB):
        - CEO (qwen2.5:14b)
        - CTO (deepseek-coder:33b)
        - Product Manager (llama3.1:8b)

      technical (3 agents, ~52.7GB):
        - CTO (deepseek-coder:33b)
        - Senior Architect (deepseek-coder:33b)
        - Senior Developer (deepseek-coder:6.7b)

      development (2 agents, ~19.7GB):
        - Senior Developer (deepseek-coder:6.7b)
        - Test Lead (codellama:13b)

      hr (2 agents, ~22GB):
        - CEO (qwen2.5:14b)
        - CHRO (llama3.1:8b)

      operations (2 agents, ~40GB):
        - Operations Head (mistral:7b)
        - CTO (deepseek-coder:33b)

      product (3 agents, ~33GB):
        - Product Manager (llama3.1:8b)
        - CEO (qwen2.5:14b)
        - UI/UX Engineer (llama3.2-vision:11b)

      quick_fix (1 agent, ~6.7GB):
        - Senior Developer (deepseek-coder:6.7b)

    RESOURCE SAVINGS:
      Before: All 9 agents running (~48GB, high CPU)
      After (quick_fix): 1 agent (~6.7GB, low CPU)
      Reduction: ~86% memory, ~75% CPU

    ROADMAP:
      ✓ Phase 1: Simple interactive delegator (CURRENT)
      - Phase 2: Pattern-based agent selection
      - Phase 3: LLM-powered intelligent selection
      - Phase 4: Dynamic mid-session spawning

    For detailed architecture, see:
    docs/architecture/DELEGATOR_ARCHITECTURE.md
    """)
  end
end
