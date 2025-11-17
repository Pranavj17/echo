# k8s/

**Context:** Kubernetes Deployment Manifests for ECHO

Kubernetes deployment configurations for running ECHO agents and infrastructure in production.

## Purpose

The k8s directory provides:
- **Production Deployment** - Kubernetes manifests for ECHO components
- **Scalability** - Horizontal scaling for agents and infrastructure
- **High Availability** - Fault-tolerant deployment configurations
- **Resource Management** - CPU/memory limits and requests
- **Monitoring** - Health checks and observability integration

## Directory Structure

```
k8s/
├── claude.md                # This file
├── namespace.yaml           # ECHO namespace
├── infrastructure/
│   ├── postgresql.yaml      # PostgreSQL StatefulSet
│   ├── redis.yaml           # Redis deployment
│   ├── ollama.yaml          # Ollama deployment
│   └── pvc.yaml             # Persistent volume claims
├── agents/
│   ├── ceo.yaml             # CEO agent deployment
│   ├── cto.yaml             # CTO agent deployment
│   ├── chro.yaml            # CHRO agent deployment
│   ├── operations_head.yaml
│   ├── product_manager.yaml
│   ├── senior_architect.yaml
│   ├── uiux_engineer.yaml
│   ├── senior_developer.yaml
│   └── test_lead.yaml
├── monitor/
│   ├── deployment.yaml      # Phoenix LiveView dashboard
│   └── service.yaml         # Dashboard service
├── shared/
│   ├── configmap.yaml       # Shared configuration
│   └── secrets.yaml         # Secrets (template)
├── ingress/
│   └── ingress.yaml         # Ingress for monitor dashboard
└── kustomization.yaml       # Kustomize configuration
```

## Architecture

### Deployment Topology

```
┌──────────────────────────────────────────────────┐
│  Kubernetes Cluster (ECHO Namespace)             │
│                                                   │
│  ┌─────────────────────────────────────────┐   │
│  │ Infrastructure (StatefulSets/Deployments)│   │
│  │  ├─ PostgreSQL (StatefulSet)            │   │
│  │  ├─ Redis (Deployment)                  │   │
│  │  └─ Ollama (Deployment, GPU-enabled)    │   │
│  └─────────────────────────────────────────┘   │
│                                                   │
│  ┌─────────────────────────────────────────┐   │
│  │ Agents (Deployments, 9 total)           │   │
│  │  ├─ CEO (qwen2.5:14b)                   │   │
│  │  ├─ CTO (deepseek-coder:33b)            │   │
│  │  ├─ CHRO (llama3.1:8b)                  │   │
│  │  └─ ... (6 more agents)                 │   │
│  └─────────────────────────────────────────┘   │
│                                                   │
│  ┌─────────────────────────────────────────┐   │
│  │ Monitor Dashboard (Phoenix LiveView)    │   │
│  │  └─ Exposed via Ingress                 │   │
│  └─────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘
```

### Resource Requirements

| Component | CPU (Request/Limit) | Memory (Request/Limit) | Storage |
|-----------|---------------------|------------------------|---------|
| **PostgreSQL** | 500m / 2 | 1Gi / 4Gi | 20Gi PVC |
| **Redis** | 250m / 1 | 512Mi / 2Gi | - |
| **Ollama** | 4 / 8 | 16Gi / 32Gi | 100Gi PVC (models) |
| **CEO** | 500m / 1 | 1Gi / 2Gi | - |
| **CTO** | 1 / 2 | 2Gi / 4Gi | - |
| **Other Agents** | 250m / 1 | 512Mi / 2Gi | - |
| **Monitor** | 250m / 500m | 512Mi / 1Gi | - |

**Total Cluster:** ~10-15 CPU cores, ~30-50Gi memory, ~120Gi storage

## Quick Start

### Prerequisites

```bash
# 1. Kubernetes cluster (v1.25+)
kubectl version

# 2. kubectl configured
kubectl get nodes

# 3. Kustomize (optional but recommended)
kustomize version

# 4. Persistent storage provisioner
kubectl get storageclass
```

### Deploy Infrastructure

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Deploy PostgreSQL
kubectl apply -f infrastructure/postgresql.yaml

# Deploy Redis
kubectl apply -f infrastructure/redis.yaml

# Deploy Ollama (requires GPU node or large CPU node)
kubectl apply -f infrastructure/ollama.yaml

# Wait for infrastructure
kubectl wait --for=condition=ready pod -l app=postgresql -n echo --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n echo --timeout=60s
kubectl wait --for=condition=ready pod -l app=ollama -n echo --timeout=600s
```

### Deploy Agents

```bash
# Deploy all agents
kubectl apply -f agents/

# Or deploy specific agent
kubectl apply -f agents/ceo.yaml

# Wait for agents
kubectl wait --for=condition=ready pod -l component=agent -n echo --timeout=600s
```

### Deploy Monitor Dashboard

```bash
kubectl apply -f monitor/deployment.yaml
kubectl apply -f monitor/service.yaml
kubectl apply -f ingress/ingress.yaml
```

### Verify Deployment

```bash
# Check all pods
kubectl get pods -n echo

# Check services
kubectl get svc -n echo

# Check PVCs
kubectl get pvc -n echo

# Access monitor dashboard
kubectl port-forward svc/echo-monitor -n echo 4000:4000
# Open http://localhost:4000
```

## Configuration

### Namespace (namespace.yaml)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: echo
  labels:
    name: echo
    environment: production
```

### PostgreSQL (infrastructure/postgresql.yaml)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: echo
spec:
  serviceName: postgresql
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_DB
          value: echo_org
        - name: POSTGRES_USER
          value: echo_org
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: echo-secrets
              key: postgres-password
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2
            memory: 4Gi
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - echo_org
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - echo_org
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: echo
spec:
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: postgresql
  clusterIP: None
```

### Agent Deployment Example (agents/ceo.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ceo
  namespace: echo
  labels:
    component: agent
    role: ceo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ceo
  template:
    metadata:
      labels:
        app: ceo
        component: agent
        role: ceo
    spec:
      containers:
      - name: ceo
        image: echo/ceo:latest
        command: ["/app/ceo"]
        args: ["--autonomous"]
        env:
        - name: DB_HOST
          value: postgresql.echo.svc.cluster.local
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: echo_org
        - name: DB_USER
          value: echo_org
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: echo-secrets
              key: postgres-password
        - name: REDIS_HOST
          value: redis.echo.svc.cluster.local
        - name: REDIS_PORT
          value: "6379"
        - name: OLLAMA_ENDPOINT
          value: http://ollama.echo.svc.cluster.local:11434
        - name: CEO_MODEL
          value: qwen2.5:14b
        - name: AUTONOMOUS_BUDGET_LIMIT
          value: "1000000"
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1
            memory: 2Gi
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pgrep -f ceo
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pgrep -f ceo
          initialDelaySeconds: 10
          periodSeconds: 5
```

### Ollama with GPU (infrastructure/ollama.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: echo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      nodeSelector:
        gpu: "true"  # Schedule on GPU nodes
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
          name: http
        volumeMounts:
        - name: models
          mountPath: /root/.ollama
        resources:
          requests:
            cpu: 4
            memory: 16Gi
            nvidia.com/gpu: 1  # Request GPU
          limits:
            cpu: 8
            memory: 32Gi
            nvidia.com/gpu: 1
        livenessProbe:
          httpGet:
            path: /api/tags
            port: 11434
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /api/tags
            port: 11434
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: ollama-models
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: echo
spec:
  ports:
  - port: 11434
    targetPort: 11434
  selector:
    app: ollama
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-models
  namespace: echo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi  # Store all 9 models (~48GB + overhead)
```

## Scaling

### Horizontal Scaling

```bash
# Scale agent replicas (for load distribution)
kubectl scale deployment ceo --replicas=3 -n echo

# Scale monitor dashboard
kubectl scale deployment echo-monitor --replicas=2 -n echo
```

**Note:** Agents are stateless and can scale horizontally for redundancy

### Vertical Scaling

Edit resource limits in deployment YAML:

```yaml
resources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 2
    memory: 4Gi
```

### Autoscaling (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ceo-hpa
  namespace: echo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ceo
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Monitoring & Observability

### Prometheus Metrics

Add Prometheus annotations to deployments:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
```

### Logging

Configure logging driver:

```yaml
spec:
  containers:
  - name: ceo
    ...
    env:
    - name: LOG_LEVEL
      value: info
    - name: LOG_FORMAT
      value: json  # Structured logging for log aggregation
```

### Health Checks

All agents should have:
- **Liveness probe** - Restart if agent crashes
- **Readiness probe** - Remove from service if not ready

## Secrets Management

### Create Secrets

```bash
# Generate secure password
export POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Create secret
kubectl create secret generic echo-secrets \
  --from-literal=postgres-password=$POSTGRES_PASSWORD \
  -n echo

# Verify
kubectl get secret echo-secrets -n echo
```

### Use External Secrets (Recommended)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: echo-secrets
  namespace: echo
spec:
  secretStoreRef:
    name: vault-backend  # Or AWS Secrets Manager, GCP Secret Manager
    kind: SecretStore
  target:
    name: echo-secrets
  data:
  - secretKey: postgres-password
    remoteRef:
      key: echo/postgres-password
```

## Networking

### Service Mesh (Optional)

Integrate with Istio for advanced traffic management:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: echo-monitor
  namespace: echo
spec:
  hosts:
  - echo-monitor.example.com
  gateways:
  - echo-gateway
  http:
  - route:
    - destination:
        host: echo-monitor
        port:
          number: 4000
```

### Network Policies

Restrict traffic between components:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: agent-network-policy
  namespace: echo
spec:
  podSelector:
    matchLabels:
      component: agent
  policyTypes:
  - Ingress
  - Egress
  ingress: []  # No incoming traffic allowed
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
  - to:
    - podSelector:
        matchLabels:
          app: ollama
    ports:
    - protocol: TCP
      port: 11434
```

## Backup & Recovery

### PostgreSQL Backups

```bash
# Create backup
kubectl exec -it postgresql-0 -n echo -- pg_dump -U echo_org echo_org > backup.sql

# Restore backup
kubectl exec -i postgresql-0 -n echo -- psql -U echo_org echo_org < backup.sql
```

### Automated Backups with CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: echo
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:16-alpine
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h postgresql -U echo_org echo_org | gzip > /backups/backup-$(date +%Y%m%d).sql.gz
            volumeMounts:
            - name: backups
              mountPath: /backups
          volumes:
          - name: backups
            persistentVolumeClaim:
              claimName: postgres-backups
          restartPolicy: OnFailure
```

## Troubleshooting

### Pod not starting

```bash
# Check pod status
kubectl get pods -n echo

# Describe pod
kubectl describe pod <pod-name> -n echo

# Check logs
kubectl logs <pod-name> -n echo

# Common issues:
# - ImagePullBackOff: Image not found
# - CrashLoopBackOff: Container crashing
# - Pending: Insufficient resources
```

### Database connection errors

```bash
# Test PostgreSQL connectivity
kubectl exec -it postgresql-0 -n echo -- psql -U echo_org -d echo_org -c "SELECT 1"

# Check PostgreSQL service
kubectl get svc postgresql -n echo

# Check PostgreSQL logs
kubectl logs postgresql-0 -n echo
```

### Ollama not responding

```bash
# Check Ollama pod
kubectl get pod -l app=ollama -n echo

# Check Ollama logs
kubectl logs -l app=ollama -n echo

# Test Ollama API
kubectl exec -it <ceo-pod> -n echo -- curl http://ollama:11434/api/tags
```

### Agent crashes

```bash
# Check agent logs
kubectl logs -l role=ceo -n echo --tail=100

# Check resource usage
kubectl top pod -l component=agent -n echo

# Restart agent
kubectl rollout restart deployment/ceo -n echo
```

## Production Best Practices

1. **Use StatefulSets for databases** - PostgreSQL should be StatefulSet
2. **Persistent volumes** - Use PVCs for data persistence
3. **Resource limits** - Set CPU/memory limits for all containers
4. **Health checks** - Configure liveness and readiness probes
5. **Secrets management** - Never hardcode secrets
6. **Namespace isolation** - Use dedicated namespace for ECHO
7. **RBAC** - Configure Role-Based Access Control
8. **Network policies** - Restrict traffic between components
9. **Monitoring** - Integrate with Prometheus/Grafana
10. **Backups** - Automated daily backups of PostgreSQL

## Related Documentation

- **Parent:** [../CLAUDE.md](../CLAUDE.md) - Project overview
- **Docker:** [../docker/claude.md](../docker/claude.md) - Docker deployment (simpler alternative)
- **Monitor:** [../monitor/claude.md](../monitor/claude.md) - Dashboard deployment
- **Agents:** [../apps/claude.md](../apps/claude.md) - Agent development

---

**Remember:** Kubernetes deployment is for production. For development, use Docker Compose (see `docker/claude.md`).
