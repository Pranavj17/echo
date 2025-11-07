#!/usr/bin/env bash
#
# ECHO System Startup
# Starts all agents + monitor dashboard
#

set -e

echo "🚀 Starting ECHO System..."

# 1. Kill any existing agents
echo "🧹 Cleaning up existing agents..."
pkill -f "apps/ceo/ceo" || true
pkill -f "apps/cto/cto" || true
pkill -f "apps/chro/chro" || true
pkill -f "apps/operations_head/operations_head" || true
pkill -f "apps/product_manager/product_manager" || true
pkill -f "apps/senior_architect/senior_architect" || true
pkill -f "apps/uiux_engineer/uiux_engineer" || true
pkill -f "apps/senior_developer/senior_developer" || true
pkill -f "apps/test_lead/test_lead" || true
pkill -f "mix phx.server" || true  # Kill monitor if running
sleep 1

# 2. Start Docker (PostgreSQL + Redis)
echo "📦 Starting infrastructure..."
docker-compose up -d
sleep 3

# 3. Export environment variables
export DB_HOST=localhost
export DB_USER=echo_org
export DB_PASSWORD=postgres
export DB_PORT=5433
export DB_NAME=echo_org
export REDIS_HOST=localhost
export REDIS_PORT=6383

# 4. Start all agents in background
echo "🤖 Starting agents..."
./run_autonomous_agents.sh &
sleep 5

# 5. Start monitor dashboard
echo "📊 Starting monitor at http://localhost:4000"
cd monitor
mkdir -p logs

# Ensure dependencies are installed (silent)
mix deps.get > /dev/null 2>&1 || true

# Start in detached mode
MIX_ENV=dev elixir --erl "-detached" -S mix phx.server > logs/monitor_phoenix.log 2>&1 &
MONITOR_PID=$!
echo $MONITOR_PID > logs/monitor.pid
echo "✅ Monitor starting (PID: $MONITOR_PID)"
cd ..

# Wait for monitor to start
echo "⏳ Waiting for monitor to start..."
sleep 10

echo ""
echo "✅ ECHO System Running!"
echo ""
echo "📊 Monitor Dashboard: http://localhost:4000"
echo "📝 Agent Logs:        tail -f logs/autonomous/*.log"
echo "📝 Monitor Log:       tail -f monitor/logs/monitor_phoenix.log"
echo ""
echo "📨 Send agenda:       ./send_agenda.sh \"Your agenda here\""
echo "🛑 Stop everything:   ./stop_echo_system.sh"
echo ""
