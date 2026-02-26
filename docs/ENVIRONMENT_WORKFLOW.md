# iOS Environment Workflow (Compose -> Staging -> Production)

This guide aligns iOS testing with backend/platform promotion flow.

## 1) Compose First (Daily Development)

1. Start backend compose stack.
2. In Xcode select scheme `traders_guild Compose Dev`.
3. Validate feature behavior against direct service ports.

Backend commands (from `traders-guild-backend`):

```bash
make start          # Start local backend/data/observability containers
make migrate        # Apply latest DB migrations inside compose auth-service
make smoke-compose  # Verify API + websocket baseline from compose
```

## 2) Local Staging Validation (Kubernetes + Kong)

1. Merge staging image bump in platform repo.
2. Confirm Argo apps healthy.
3. Run staging smoke checks.
4. In Xcode select `traders_guild Staging K8s` and test flows.

Platform commands (from `traders-guild-platform`):

```bash
make staging-pr-merge-latest  # Merge newest staging image automation PR
make argocd-apps-local        # Confirm local Argo apps are Synced/Healthy
make smoke-staging-local      # Run schema + Kong route + websocket checks
```

Scheme/env requirements:

- `TG_API_ROUTING_MODE=API_GATEWAY`
- Simulator: `TG_GATEWAY_BASE_URL_DEV=http://localhost:30080/api/v1`
- Device: `TG_GATEWAY_BASE_URL_DEV_DEVICE=http://<mac-lan-ip>:30080/api/v1`

## 3) Production Promotion Validation

1. Promote staging image map to production.
2. Sync production Argo apps.
3. Run production smoke checks.
4. Start prod Kong port-forward and use `traders_guild Prod K8s` scheme for iOS regression tests.

Platform commands:

```bash
make prod-promote-validate  # Verify staged tags exist in Artifact Registry
make prod-promote-open-pr   # Create production promotion PR from validated tags
make argocd-apps-prod       # Check production Argo app health/sync
make smoke-prod             # Run production schema + Kong smoke checks
make kong-prod-port-forward # Expose prod Kong to simulator at localhost:30081
```

Scheme/env requirements for `traders_guild Prod K8s`:

- `TG_API_ROUTING_MODE=API_GATEWAY`
- Simulator: `TG_GATEWAY_BASE_URL_DEV=http://localhost:30081/api/v1`
- Device: `TG_GATEWAY_BASE_URL_DEV_DEVICE=http://<mac-lan-ip>:30081/api/v1`

## 4) Access and Debugging

For backend/platform observability and admin access, use the platform docs:

- `traders-guild-platform/docs/OPERATIONS_END_TO_END.md`
- `traders-guild-platform/docs/LOCAL_STAGING_OPERATIONS.md`
- `traders-guild-platform/docs/PRODUCTION_OPERATIONS.md`
