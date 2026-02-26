# iOS Environment Routing

Use shared Xcode schemes to switch between local Compose and Kubernetes gateway testing.

## Schemes

- `traders_guild Compose Dev`
- `traders_guild Staging K8s`

If a scheme does not show in Xcode:

1. `Product` -> `Scheme` -> `Manage Schemes...`
2. Ensure the scheme is listed and `Shared` is enabled.
3. Reopen the project if needed.

## Compose Development Mode

Use scheme: `traders_guild Compose Dev`

- `TG_API_ROUTING_MODE=DIRECT_SERVICES`
- Simulator connects directly to compose service ports (`localhost:8000..8006`)
- Device mode uses the app-configured Mac LAN IP mappings for direct service ports

## Staging Kubernetes Mode

Use scheme: `traders_guild Staging K8s`

- `TG_API_ROUTING_MODE=API_GATEWAY`
- Simulator gateway URL: `http://localhost:30080/api/v1`
- Device gateway URL: `http://<YOUR_MAC_LAN_IP>:30080/api/v1`
  - Set via `TG_GATEWAY_BASE_URL_DEV_DEVICE`

## Production-Like Validation

Production remains private/non-public. Use the same gateway mode behavior and validate backend/platform with smoke checks in the platform repo before iOS release work.
