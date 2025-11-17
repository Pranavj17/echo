#!/usr/bin/env bash
#
# ECHO System Shutdown
# Stops all agents + monitor dashboard
#

echo "🛑 Stopping ECHO System..."

# 1. Kill all agents
echo "🤖 Stopping agents..."
pkill -f "apps/ceo/ceo" || true
pkill -f "apps/cto/cto" || true
pkill -f "apps/chro/chro" || true
pkill -f "apps/operations_head/operations_head" || true
pkill -f "apps/product_manager/product_manager" || true
pkill -f "apps/senior_architect/senior_architect" || true
pkill -f "apps/uiux_engineer/uiux_engineer" || true
pkill -f "apps/senior_developer/senior_developer" || true
pkill -f "apps/test_lead/test_lead" || true

# 2. Kill monitor dashboard
echo "📊 Stopping monitor..."
if [ -f monitor/logs/monitor.pid ]; then
    MONITOR_PID=$(cat monitor/logs/monitor.pid)
    kill $MONITOR_PID 2>/dev/null || true
    rm -f monitor/logs/monitor.pid
fi
pkill -f "mix phx.server" || true  # Fallback

# 3. Clean up PID files
rm -f logs/autonomous/*.pid 2>/dev/null || true

# 4. Stop Docker (optional - uncomment if you want to stop infrastructure)
# echo "📦 Stopping infrastructure..."
# docker-compose down

echo ""
echo "✅ ECHO System Stopped!"
echo ""
echo "Infrastructure (PostgreSQL/Redis) still running."
echo "To stop Docker: docker-compose down"
echo ""
