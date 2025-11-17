# Database Troubleshooting

Common PostgreSQL troubleshooting steps for ECHO.

## Connection Refused

**Symptom:** `(DBConnection.ConnectionError) connection refused`

**Solution:**
```bash
# Check if PostgreSQL is running
docker ps | grep echo_postgres

# Start PostgreSQL if stopped
docker-compose up -d

# Verify connection
PGPASSWORD=postgres psql -h 127.0.0.1 -p 5433 -U echo_org -d echo_org -c "SELECT 1"
```

## Migration Errors

**Symptom:** `** (Ecto.MigrationError) ...`

**Solution:**
```bash
# Check migration status
cd shared && mix ecto.migrations

# Run pending migrations
mix ecto.migrate

# If migration fails, rollback and retry
mix ecto.rollback
mix ecto.migrate
```

## Stale Connections

**Symptom:** `(DBConnection.ConnectionError) tcp recv: closed`

**Solution:**
```bash
# Reset test database
cd shared && MIX_ENV=test mix ecto.reset

# For development
cd shared && mix ecto.drop && mix ecto.create && mix ecto.migrate
```

## Permission Issues

**Symptom:** `FATAL: permission denied for database`

**Solution:**
```sql
-- Connect as postgres user
psql -h 127.0.0.1 -p 5433 -U postgres

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE echo_org TO echo_org;
GRANT ALL ON SCHEMA public TO echo_org;
```

## Database Not Found

**Symptom:** `FATAL: database "echo_org" does not exist`

**Solution:**
```bash
cd shared && mix ecto.create && mix ecto.migrate
```

**Used in:**
- CLAUDE.md (main troubleshooting section)
- apps/echo_shared/claude.md
- test/claude.md
- docker/claude.md
