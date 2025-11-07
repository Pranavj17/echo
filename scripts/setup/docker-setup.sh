#!/bin/bash
# Docker Setup for ECHO Project
# Sets up PostgreSQL and Redis containers

set -e

ECHO_DIR="/Users/pranav/Documents/echo"
cd "$ECHO_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           ECHO Docker Setup - PostgreSQL & Redis              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration
REDIS_PORT=6383
DB_PORT=5433
DB_NAME=echo_org
DB_USER=postgres
DB_PASSWORD=postgres

echo -e "${YELLOW}Step 1: Check Docker${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    echo "Please start Docker Desktop or run: sudo systemctl start docker"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"
echo ""

echo -e "${YELLOW}Step 2: Setup Redis${NC}"
if docker ps -a | grep -q "echo-redis"; then
    echo "Redis container exists. Checking status..."
    if docker ps | grep -q "echo-redis.*Up"; then
        echo -e "${GREEN}✓ Redis already running${NC}"
    else
        echo "Starting existing Redis container..."
        docker start echo-redis
        sleep 2
        echo -e "${GREEN}✓ Redis started${NC}"
    fi
else
    echo "Creating new Redis container..."
    docker run -d \
        --name echo-redis \
        -p $REDIS_PORT:6379 \
        --restart unless-stopped \
        redis:7-alpine

    sleep 2
    echo -e "${GREEN}✓ Redis created and started${NC}"
fi

# Verify Redis
if docker exec echo-redis redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Redis responding on port $REDIS_PORT${NC}"
else
    echo -e "${RED}❌ Redis not responding${NC}"
    exit 1
fi
echo ""

echo -e "${YELLOW}Step 3: Setup PostgreSQL${NC}"
if docker ps -a | grep -q "echo-postgres"; then
    echo "PostgreSQL container exists. Checking status..."
    if docker ps | grep -q "echo-postgres.*Up"; then
        echo -e "${GREEN}✓ PostgreSQL already running${NC}"
    else
        echo "Starting existing PostgreSQL container..."
        docker start echo-postgres
        sleep 3
        echo -e "${GREEN}✓ PostgreSQL started${NC}"
    fi
else
    echo "Creating new PostgreSQL container..."
    docker run -d \
        --name echo-postgres \
        -p $DB_PORT:5432 \
        -e POSTGRES_PASSWORD=$DB_PASSWORD \
        -e POSTGRES_DB=$DB_NAME \
        --restart unless-stopped \
        postgres:16-alpine

    sleep 5
    echo -e "${GREEN}✓ PostgreSQL created and started${NC}"
fi

# Verify PostgreSQL
if docker exec echo-postgres pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL responding on port $DB_PORT${NC}"
else
    echo -e "${RED}❌ PostgreSQL not responding${NC}"
    exit 1
fi
echo ""

echo -e "${YELLOW}Step 4: Run database migrations${NC}"
cd shared
echo "Running Ecto migrations..."
export DB_HOST=localhost
export DB_PORT=$DB_PORT
export DB_NAME=$DB_NAME
export DB_USER=$DB_USER
export DB_PASSWORD=$DB_PASSWORD

# Wait a bit more for DB to be fully ready
sleep 2

# Create database if it doesn't exist
mix ecto.create 2>/dev/null || echo "Database already exists"

# Run migrations
mix ecto.migrate

echo -e "${GREEN}✓ Migrations complete${NC}"
echo ""

cd "$ECHO_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     Setup Complete!                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}Docker Containers:${NC}"
echo "  Redis:      echo-redis (port $REDIS_PORT)"
echo "  PostgreSQL: echo-postgres (port $DB_PORT)"
echo ""

echo -e "${GREEN}Database:${NC}"
echo "  Name:     $DB_NAME"
echo "  User:     $DB_USER"
echo "  Password: $DB_PASSWORD"
echo "  Host:     localhost"
echo "  Port:     $DB_PORT"
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo "  Start containers:    docker start echo-redis echo-postgres"
echo "  Stop containers:     docker stop echo-redis echo-postgres"
echo "  View logs (Redis):   docker logs -f echo-redis"
echo "  View logs (PG):      docker logs -f echo-postgres"
echo "  Connect to Redis:    docker exec -it echo-redis redis-cli"
echo "  Connect to DB:       docker exec -it echo-postgres psql -U postgres -d $DB_NAME"
echo "  Remove containers:   docker rm -f echo-redis echo-postgres"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Ensure Ollama is running: ollama serve"
echo "  2. Run Day 2 training: ./day2_training.sh"
echo ""

# Show container status
echo -e "${YELLOW}Container Status:${NC}"
docker ps --filter "name=echo-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
