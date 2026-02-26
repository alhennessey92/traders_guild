# iOS Environment Workflow (Compose -> Staging -> Production)

This guide aligns iOS testing with backend/platform promotion flow.

## 1) Compose First (Daily Development)

1. Start backend compose stack.
2. In Xcode select scheme `traders_guild Compose Dev`.
3. Validate feature behavior against direct service ports.

Backend commands (from `traders-guild-backend`):

```bash
make start
make migrate
make smoke-compose
```

## 2) Local Staging Validation (Kubernetes + Kong)

1. Merge staging image bump in platform repo.
2. Confirm Argo apps healthy.
3. Run staging smoke checks.
4. In Xcode select `traders_guild Staging K8s` and test flows.

Platform commands (from `traders-guild-platform`):

```bash
make staging-pr-merge-latest
make argocd-apps-local
make smoke-staging-local
```

Scheme/env requirements:

- `TG_API_ROUTING_MODE=API_GATEWAY`
- Simulator: `TG_GATEWAY_BASE_URL_DEV=http://localhost:30080/api/v1`
- Device: `TG_GATEWAY_BASE_URL_DEV_DEVICE=http://<mac-lan-ip>:30080/api/v1`

## 3) Production Promotion Validation

1. Promote staging image map to production.
2. Sync production Argo apps.
3. Run production smoke checks.
4. Regression-test iOS against production-like behavior as needed.

Platform commands:

```bash
make prod-promote-validate
make prod-promote-open-pr
make argocd-apps-prod
make smoke-prod
```

## 4) Access and Debugging

For backend/platform observability and admin access, use the platform docs:

- `traders-guild-platform/docs/OPERATIONS_END_TO_END.md`
- `traders-guild-platform/docs/LOCAL_STAGING_OPERATIONS.md`
- `traders-guild-platform/docs/PRODUCTION_OPERATIONS.md`
