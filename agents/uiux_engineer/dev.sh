#!/bin/bash
#
# Development launcher for UIUX_ENGINEER MCP server
#
# This script starts the UIUX_ENGINEER agent in development mode with hot-reloading
# enabled via mix run. Use this during development instead of the built escript.
#

set -e

cd "$(dirname "$0")"

# Check if dependencies are installed
if [ ! -d "deps" ]; then
    echo "Dependencies not found. Installing..."
    mix deps.get
fi

# Check if shared library is compiled
if [ ! -d "../../shared/_build" ]; then
    echo "Shared library not compiled. Building..."
    cd ../../shared
    mix deps.get
    mix compile
    cd -
fi

# Run in development mode
echo "Starting UIUX_ENGINEER MCP server in development mode..."
echo "Press Ctrl+C to stop"
echo ""

exec mix run --no-halt
