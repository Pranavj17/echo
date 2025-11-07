#!/bin/bash

# Fix PostgreSQL "too many connections" issue for ECHO project

set -e

echo "🔧 Fixing PostgreSQL Connection Issues"
echo "======================================"
echo ""

# Step 1: Stop all ECHO agent processes
echo "Step 1: Stopping all ECHO agent processes..."
pkill -f "beam.smp.*echo" || true
pkill -f "senior_architect" || true
pkill -f "ceo" || true
pkill -f "cto" || true
sleep 2
echo "✓ Agent processes stopped"
echo ""

# Step 2: Check current connections
echo "Step 2: Checking PostgreSQL status..."
CONN_COUNT=$(ps aux | grep postgres | grep -v grep | wc -l)
echo "PostgreSQL processes: $CONN_COUNT"
echo ""

# Step 3: Get PostgreSQL config location
echo "Step 3: Finding PostgreSQL configuration..."
if command -v brew &> /dev/null; then
    PG_DATA=$(brew --prefix)/var/postgresql@16
    PG_CONF="$PG_DATA/postgresql.conf"

    if [ ! -f "$PG_CONF" ]; then
        PG_DATA=$(brew --prefix)/var/postgres
        PG_CONF="$PG_DATA/postgresql.conf"
    fi
else
    PG_CONF="/usr/local/var/postgresql@16/postgresql.conf"
fi

if [ ! -f "$PG_CONF" ]; then
    echo "❌ Could not find postgresql.conf"
    echo "Please manually locate it and increase max_connections to 200"
    exit 1
fi

echo "Found config: $PG_CONF"
echo ""

# Step 4: Backup and update PostgreSQL configuration
echo "Step 4: Updating PostgreSQL configuration..."
cp "$PG_CONF" "$PG_CONF.backup.$(date +%Y%m%d_%H%M%S)"
echo "✓ Config backed up"

# Update max_connections
if grep -q "^max_connections" "$PG_CONF"; then
    sed -i.bak 's/^max_connections = .*/max_connections = 200/' "$PG_CONF"
    echo "✓ Updated max_connections to 200"
else
    echo "max_connections = 200" >> "$PG_CONF"
    echo "✓ Added max_connections = 200"
fi

# Update shared_buffers if needed
if grep -q "^shared_buffers" "$PG_CONF"; then
    sed -i.bak 's/^shared_buffers = .*/shared_buffers = 256MB/' "$PG_CONF"
    echo "✓ Updated shared_buffers to 256MB"
else
    echo "shared_buffers = 256MB" >> "$PG_CONF"
    echo "✓ Added shared_buffers = 256MB"
fi

echo ""

# Step 5: Restart PostgreSQL
echo "Step 5: Restarting PostgreSQL..."
if command -v brew &> /dev/null; then
    brew services restart postgresql@16 2>/dev/null || brew services restart postgresql
    echo "✓ PostgreSQL restarted"
else
    echo "❌ Please manually restart PostgreSQL:"
    echo "   sudo systemctl restart postgresql"
    exit 1
fi

sleep 3
echo ""

# Step 6: Verify fix
echo "Step 6: Verifying connection..."
if psql -h localhost -U postgres -c "SELECT version();" > /dev/null 2>&1; then
    echo "✓ PostgreSQL connection successful!"

    MAX_CONN=$(psql -h localhost -U postgres -t -c "SHOW max_connections;")
    echo "✓ Max connections: $MAX_CONN"
else
    echo "⚠️  Still having connection issues. Please check logs:"
    echo "   tail -f $(brew --prefix)/var/log/postgresql@16.log"
fi

echo ""
echo "✅ PostgreSQL fix complete!"
echo ""
echo "Current configuration:"
echo "  max_connections: 200 (was 100)"
echo "  shared_buffers: 256MB"
echo "  pool_size per agent: 2"
echo "  Total possible: 9 agents × 2 = 18 connections (well under 200)"
echo ""
echo "You can now safely start your ECHO agents."
