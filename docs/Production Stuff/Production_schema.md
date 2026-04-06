# Traders Guild — Phase 1 GCP Infrastructure Plan

> **Target:** 0–50 users · Single-node GKE · Cost-optimised · Production-like architecture

---

## Cost Summary

| Line Item | Detail | Est. Monthly |
|---|---|---|
| GKE cluster management | Single zonal cluster | **$0** |
| Compute — `e2-standard-2` | 2 vCPU / 8GB RAM, SUD ~20% | **~$39** |
| Storage — `pd-ssd` 30GB | TimescaleDB PVC | **~$5** |
| Storage — `pd-balanced` 30GB | OS + general workloads | **~$2.50** |
| Static external IP | NodePort ingress, no LB | **~$1.50** |
| Egress | 0–50 users, minimal | **~$2–3** |
| **Total** | | **~$50–51/month** |

> No Loki in Phase 1. Prometheus + Grafana cover metrics and alerting. Loki added in Phase 2 on the larger node.

---

## Cluster Configuration

```yaml
Provider:       GCP — Google Kubernetes Engine
Cluster type:   Standard (not Autopilot)
Mode:           Zonal (single zone, e.g. us-central1-a)
Node count:     1
Node type:      e2-standard-2 (2 vCPU / 8GB RAM)
OS disk:        pd-balanced 30GB
GKE version:    Stable channel (auto-patching)
Management fee: $0 (first zonal cluster per billing account)
Discount:       Sustained Use Discount (~20%) — automatic, no commitment
```

> **Phase 2 upgrade path:** When you're ready, provision an `e2-standard-4` with a 1-year CUD (~$61/month) and migrate. Since Phase 1 has no CUD, there is no penalty or cancellation — simply reprovision. PVCs survive the node replacement.

---

## Networking

```yaml
Strategy:       NodePort + reserved static external IP (no Cloud Load Balancer)
Saving:         ~$18/month vs a standard LoadBalancer service
Kong NodePort:  Exposed on port 30080 (HTTP) and 30443 (HTTPS)
Static IP:      Reserved in same zone — ~$1.46/month when attached to a running instance
DNS:            Point your domain A record at the static IP
TLS:            cert-manager + Let's Encrypt, terminating at Kong
```

Kong service manifest:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kong-proxy
  namespace: kong
spec:
  type: NodePort
  selector:
    app: kong
  ports:
    - name: http
      port: 80
      targetPort: 8000
      nodePort: 30080
    - name: https
      port: 443
      targetPort: 8443
      nodePort: 30443
```

---

## Services & Resource Allocation

Full 8GB memory budget across all workloads:

```
┌─────────────────────────────────────────────────────────┐
│ Service              Request      Limit                  │
├─────────────────────────────────────────────────────────┤
│ TimescaleDB          1.5GB        2.0GB                  │
│ Redis                256MB        512MB                  │
│ Kong                 384MB        768MB                  │
│ Kong Postgres        256MB        512MB                  │
│ FastAPI services     384MB        768MB  (all pods)      │
│ ArgoCD               384MB        768MB                  │
│ Prometheus           256MB        512MB                  │
│ Grafana              128MB        256MB                  │
│ System overhead      ~1.0GB                              │
├─────────────────────────────────────────────────────────┤
│ Total used           ~4.5GB / 8GB available   ✓         │
└─────────────────────────────────────────────────────────┘
```

~3.5GB headroom before the node becomes a constraint.

---

## Service Configurations

### TimescaleDB

```yaml
# Deployment resource limits
resources:
  requests:
    memory: "1536Mi"
    cpu: "250m"
  limits:
    memory: "2048Mi"
    cpu: "1000m"

# PVC — pd-ssd for IO-sensitive time-series writes
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: timescaledb-pvc
spec:
  storageClassName: premium-rwo   # pd-ssd on GKE
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 30Gi
```

Key Postgres settings for Phase 1 scale:

```sql
max_connections = 50          -- default 100 wastes shared_buffers at this scale
shared_buffers = 384MB        -- ~25% of container memory limit
work_mem = 8MB
maintenance_work_mem = 128MB
effective_cache_size = 1GB
```

TimescaleDB-specific:

```sql
-- 1-minute base candles only; higher timeframes via continuous aggregates
-- time_bucket() aggregates for 5m, 15m, 1h, 4h, 1d
-- Compression policy after 7 days to reduce disk footprint
SELECT add_compression_policy('candles_1m', INTERVAL '7 days');
```

---

### Redis

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "50m"
  limits:
    memory: "512Mi"
    cpu: "250m"
```

```conf
# redis.conf — Phase 1 settings
maxmemory 400mb
maxmemory-policy allkeys-lru   # evict LRU keys when near limit
save ""                        # disable RDB snapshots (pub/sub only, no persistence needed)
appendonly no
```

---

### Kong (with Postgres)

Kong retains full Admin API with its own Postgres — not DB-less — so you keep declarative config, plugin management, and route inspection.

```yaml
# Kong
resources:
  requests:
    memory: "384Mi"
    cpu: "100m"
  limits:
    memory: "768Mi"
    cpu: "500m"

# Kong Postgres
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "250m"
```

Kong plugin config (applied via Admin API or decK):

```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 120
      policy: local

  - name: jwt
    config:
      secret_is_base64: false

  # WebSocket connections — increase timeouts to prevent WS session drops
  - name: proxy-cache
    config:
      response_code: [200]
      request_method: [GET]
      content_type: [application/json]
```

Kong nginx upstream settings (in values.yaml):

```yaml
env:
  nginx_proxy_read_timeout: "3600"       # Keep WebSocket connections alive
  nginx_proxy_send_timeout: "3600"
  nginx_upstream_keepalive: "60"
  nginx_upstream_keepalive_timeout: "3600"
```

---

### FastAPI Services

```yaml
resources:
  requests:
    memory: "192Mi"
    cpu: "100m"
  limits:
    memory: "384Mi"
    cpu: "500m"
```

> If running multiple FastAPI pods (e.g. core-service, realtime-service), set these per pod. Total budget is ~384MB request / 768MB limit across all pods.

WebSocket/real-time service:

```yaml
# realtime-service — allow higher replica count without memory blowout
# WebSocket pods are lightweight; scale replicas not memory
replicas: 1   # Phase 1; bump to 2+ in Phase 2
```

---

### ArgoCD (Resource-Constrained Mode)

```yaml
# Disable unused controllers to reclaim ~200MB
configs:
  params:
    application.namespaces: ""

# In argocd-cmd-params-cm:
# Disable applicationset and notifications controllers
server.enable.gzip: "true"
```

ArgoCD component resource limits:

```yaml
# argocd-server
resources:
  requests: { memory: "128Mi", cpu: "50m" }
  limits:   { memory: "256Mi", cpu: "250m" }

# argocd-repo-server
resources:
  requests: { memory: "128Mi", cpu: "50m" }
  limits:   { memory: "256Mi", cpu: "250m" }

# argocd-application-controller
resources:
  requests: { memory: "128Mi", cpu: "100m" }
  limits:   { memory: "256Mi", cpu: "500m" }
```

---

### Prometheus

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

Critical settings to prevent runaway disk/memory usage:

```yaml
# values.yaml (kube-prometheus-stack)
prometheus:
  prometheusSpec:
    retention: 7d                          # Default is 15d — halves disk usage
    retentionSize: "4GB"                   # Hard cap — prevents PVC overflow
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: standard-rwo   # pd-balanced is fine for metrics
          resources:
            requests:
              storage: 8Gi

    # Scrape only what you need at this scale
    scrapeInterval: 30s                    # Default 15s doubles storage consumption
    evaluationInterval: 30s
```

Scrape targets for Phase 1:

```yaml
# Scrape: FastAPI (custom /metrics), Kong, Redis, Postgres, kube-state-metrics
# Skip: node-exporter cadvisor (optional, adds ~50MB RAM)
```

---

### Grafana

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "50m"
  limits:
    memory: "256Mi"
    cpu: "250m"
```

```yaml
# Persist dashboards via ConfigMap (no Grafana DB migrations needed)
grafana.ini:
  server:
    root_url: "https://yourdomain.com/grafana"
  auth.anonymous:
    enabled: false

# Use Prometheus as the sole datasource in Phase 1
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-operated:9090
        isDefault: true
```

Recommended dashboards to import (Grafana dashboard IDs):

| Dashboard | ID |
|---|---|
| Kubernetes cluster overview | 315 |
| FastAPI metrics | 17175 |
| PostgreSQL / TimescaleDB | 9628 |
| Redis | 11835 |
| Kong | 7424 |

---

## Storage Summary

| Volume | Type | Size | Used by |
|---|---|---|---|
| `timescaledb-pvc` | `pd-ssd` | 30GB | TimescaleDB data |
| `prometheus-pvc` | `pd-balanced` | 8GB | Metrics (7-day retention) |
| Node OS disk | `pd-balanced` | 30GB | System + all container layers |

> No Loki PVC or GCS bucket in Phase 1. Add in Phase 2 with GCS backend (~$0.02/GB/month).

---

## Monitoring Coverage — Phase 1

Without Loki you still get:

| Capability | Tool | Available |
|---|---|---|
| Infrastructure metrics | Prometheus | ✓ |
| Application metrics | Prometheus + FastAPI `/metrics` | ✓ |
| Dashboards | Grafana | ✓ |
| Alerting | Prometheus AlertManager | ✓ |
| DB query performance | pg_stat_statements → Prometheus | ✓ |
| WebSocket connection count | Custom FastAPI metric | ✓ |
| Log querying | ✗ (Phase 2) | — |
| Log-based alerting | ✗ (Phase 2) | — |

For early stage, `kubectl logs` covers the gap adequately.

---

## Phase 2 Trigger Checklist

Upgrade to `e2-standard-4` + CUD when any of the following are true:

- [ ] Node memory consistently above 70% (~5.6GB used)
- [ ] TimescaleDB slow query logs showing buffer contention
- [ ] FastAPI pods OOMKilled more than once
- [ ] User count approaching 30–50 with active WebSocket sessions
- [ ] You want Loki added back for log querying
- [ ] You want to isolate TimescaleDB to a tainted node

Phase 2 cost target with CUD: **~$78–82/month**