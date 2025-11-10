# docker/

**Context:** Docker & Kubernetes Deployment

This directory contains Docker configuration and Kubernetes manifests for deploying ECHO to containerized environments.

## Purpose

Docker support enables:
- **Containerized Deployment** - Package agents and infrastructure in containers
- **Environment Consistency** - Same setup across dev/staging/production
- **Orchestration** - Kubernetes deployment for scalability
- **Easy Setup** - Docker Compose for local development

## Directory Structure

```
docker/
├── claude.md                  # This file
├── docker-compose.yml        # Local development setup
└── [individual Dockerfiles for agents]
```

Note: Kubernetes manifests are in `../k8s/` directory

## Docker Compose Setup

**Purpose:** Run entire ECHO system locally with Docker

**File:** `docker-compose.yml`

```yaml
version: '3.8'

services:
  # Infrastructure
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: echo_org
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  # Agents
  echo-ceo:
    build:
      context: ../agents/ceo
      dockerfile: Dockerfile
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      DB_HOST: postgres
      DB_NAME: echo_org
      REDIS_HOST: redis
      OLLAMA_ENDPOINT: http://host.docker.internal:11434
    command: ["./ceo", "--autonomous"]

  echo-cto:
    build:
      context: ../agents/cto
      dockerfile: Dockerfile
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      DB_HOST: postgres
      REDIS_HOST: redis
      OLLAMA_ENDPOINT: http://host.docker.internal:11434
    command: ["./cto", "--autonomous"]

  # ... (repeat for other 7 agents)

  # Monitor Dashboard
  monitor:
    build:
      context: ../monitor
      dockerfile: Dockerfile
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - "4000:4000"
    environment:
      DB_HOST: postgres
      REDIS_HOST: redis
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}

volumes:
  postgres_data:
  redis_data:
```

### Usage

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Rebuild and restart
docker-compose up -d --build

# Run database migrations
docker-compose exec postgres psql -U postgres -d echo_org < migrations.sql
```

## Agent Dockerfile Template

```dockerfile
# Multi-stage build for smaller image
FROM elixir:1.18-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base git

WORKDIR /app

# Copy shared library first (dependency)
COPY ../../shared /app/shared
WORKDIR /app/shared
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix compile

# Copy agent code
WORKDIR /app/agent
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
COPY lib lib
COPY config config

# Build escript executable
RUN MIX_ENV=prod mix escript.build

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache bash openssl ncurses-libs

WORKDIR /app

# Copy executable from builder
COPY --from=builder /app/agent/agent_name ./agent_name

# Create non-root user
RUN adduser -D -u 1000 echo && \
    chown -R echo:echo /app

USER echo

# Run agent
CMD ["./agent_name", "--autonomous"]
```

## Kubernetes Deployment

**Location:** `../k8s/` directory

### Architecture

```
k8s/
├── namespace.yml              # echo-org namespace
├── postgres.yml               # PostgreSQL StatefulSet
├── redis.yml                  # Redis Deployment
├── agents/
│   ├── ceo.yml               # CEO agent Deployment
│   ├── cto.yml               # CTO agent Deployment
│   └── ... (other agents)
└── monitor.yml                # Monitor dashboard Deployment + Service
```

### Namespace

```yaml
# k8s/namespace.yml
apiVersion: v1
kind: Namespace
metadata:
  name: echo-org
  labels:
    name: echo-org
```

### PostgreSQL StatefulSet

```yaml
# k8s/postgres.yml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: echo-org
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: echo_org
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

### Agent Deployment Template

```yaml
# k8s/agents/ceo.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-ceo
  namespace: echo-org
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-ceo
      role: ceo
  template:
    metadata:
      labels:
        app: echo-ceo
        role: ceo
    spec:
      containers:
      - name: ceo
        image: ghcr.io/your-org/echo-ceo:latest
        env:
        - name: DB_HOST
          value: postgres
        - name: DB_NAME
          value: echo_org
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: REDIS_HOST
          value: redis
        - name: OLLAMA_ENDPOINT
          value: http://ollama-service:11434
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "pgrep -f ceo"
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "pgrep -f ceo"
          initialDelaySeconds: 10
          periodSeconds: 10
```

### Monitor Service

```yaml
# k8s/monitor.yml
apiVersion: v1
kind: Service
metadata:
  name: monitor
  namespace: echo-org
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 4000
    protocol: TCP
  selector:
    app: monitor
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitor
  namespace: echo-org
spec:
  replicas: 2
  selector:
    matchLabels:
      app: monitor
  template:
    metadata:
      labels:
        app: monitor
    spec:
      containers:
      - name: monitor
        image: ghcr.io/your-org/echo-monitor:latest
        ports:
        - containerPort: 4000
        env:
        - name: DB_HOST
          value: postgres
        - name: REDIS_HOST
          value: redis
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: monitor-secret
              key: secret_key_base
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

## Deployment Commands

### Docker Compose

```bash
# Quick start for local development
./docker-setup.sh

# Or manually:
cd docker
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f echo-ceo

# Restart specific service
docker-compose restart echo-cto

# Stop everything
docker-compose down

# Clean up volumes
docker-compose down -v
```

### Kubernetes

```bash
# Create namespace
kubectl apply -f k8s/namespace.yml

# Create secrets
kubectl create secret generic postgres-secret \
  --from-literal=username=postgres \
  --from-literal=password=YOUR_PASSWORD \
  -n echo-org

# Deploy infrastructure
kubectl apply -f k8s/postgres.yml
kubectl apply -f k8s/redis.yml

# Wait for infrastructure to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n echo-org --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n echo-org --timeout=300s

# Deploy agents
kubectl apply -f k8s/agents/

# Deploy monitor
kubectl apply -f k8s/monitor.yml

# Check status
kubectl get pods -n echo-org
kubectl get services -n echo-org

# View logs
kubectl logs -f deployment/echo-ceo -n echo-org

# Access monitor dashboard
kubectl port-forward service/monitor 4000:80 -n echo-org
# Open http://localhost:4000
```

## Building & Pushing Images

### Build Script

```bash
#!/bin/bash
set -euo pipefail

REGISTRY="ghcr.io/your-org"
VERSION=$(cat VERSION)

# Build all agent images
for agent in ceo cto chro operations_head product_manager senior_architect uiux_engineer senior_developer test_lead; do
  echo "Building echo-$agent:$VERSION..."
  docker build -t "$REGISTRY/echo-$agent:$VERSION" \
    -t "$REGISTRY/echo-$agent:latest" \
    -f "agents/$agent/Dockerfile" \
    .
done

# Build monitor image
echo "Building echo-monitor:$VERSION..."
docker build -t "$REGISTRY/echo-monitor:$VERSION" \
  -t "$REGISTRY/echo-monitor:latest" \
  -f "monitor/Dockerfile" \
  .

echo "Build complete!"
```

### Push to Registry

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Push all images
for agent in ceo cto chro operations_head product_manager senior_architect uiux_engineer senior_developer test_lead; do
  docker push "$REGISTRY/echo-$agent:$VERSION"
  docker push "$REGISTRY/echo-$agent:latest"
done

docker push "$REGISTRY/echo-monitor:$VERSION"
docker push "$REGISTRY/echo-monitor:latest"
```

## Environment Configuration

### Development (.env.dev)

```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=echo_org
DB_USER=postgres
DB_PASSWORD=postgres

REDIS_HOST=localhost
REDIS_PORT=6379

OLLAMA_ENDPOINT=http://localhost:11434
```

### Production (.env.prod)

```bash
DB_HOST=postgres.production.internal
DB_PORT=5432
DB_NAME=echo_org
DB_USER=echo_prod
DB_PASSWORD=${DB_PASSWORD}  # From secret

REDIS_HOST=redis.production.internal
REDIS_PORT=6379

OLLAMA_ENDPOINT=http://ollama.production.internal:11434
```

## Troubleshooting

### Container won't start

**Debug:**
```bash
# Check logs
docker logs echo-ceo

# Interactive shell
docker exec -it echo-ceo /bin/sh

# Check health
docker inspect echo-ceo | grep -A 10 Health
```

### Database connection errors

**Debug:**
```bash
# Test from container
docker exec echo-ceo psql -h postgres -U postgres -d echo_org -c "SELECT 1"

# Check network
docker network inspect docker_default
```

### Redis connection errors

**Debug:**
```bash
# Test from container
docker exec echo-ceo redis-cli -h redis ping

# Check Redis logs
docker logs redis
```

### Image size too large

**Optimize:**
- Use multi-stage builds
- Use alpine base images
- Clean up build artifacts
- Don't copy unnecessary files

## LocalCode for Docker Questions

For quick Docker deployment queries, use **LocalCode** (see `../CLAUDE.md` Rule 8):

```bash
source ./scripts/llm/localcode_quick.sh
lc_start
lc_query "How do I build Docker images for ECHO agents?"
lc_query "Explain the docker-compose setup"
lc_end
```

## Related Documentation

- **Parent:** [../CLAUDE.md](../CLAUDE.md) - Project overview
- **Quick Start:** [../DOCKER_QUICKSTART.md](../DOCKER_QUICKSTART.md) - Docker setup guide
- **Scripts:** [../scripts/claude.md](../scripts/claude.md) - docker-setup.sh details

---

**Remember:** Docker is for deployment. For local development, running agents directly is simpler and faster.
