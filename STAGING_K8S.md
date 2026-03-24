# iOS Environment Routing

Use shared Xcode schemes to switch between local Compose and Kubernetes gateway testing.

## Schemes

- `traders_guild Compose Dev`
- `traders_guild Staging K8s`
- `traders_guild Prod K8s`
- `traders_guild Hetzner Remote`

If a scheme does not show in Xcode:

1. `Product` -> `Scheme` -> `Manage Schemes...`
2. Ensure the scheme is listed and `Shared` is enabled.
3. Reopen the project if needed.

## Compose Development Mode

Use scheme: `traders_guild Compose Dev`

- `TG_API_ROUTING_MODE=DIRECT_SERVICES` (client calls service ports directly)
- Simulator connects to compose service ports (`localhost:8000..8006`)
- Device mode uses app-configured Mac LAN IP mappings for direct service ports

## Staging Kubernetes Mode

Use scheme: `traders_guild Staging K8s`

- `TG_API_ROUTING_MODE=API_GATEWAY` (client calls Kong gateway)
- Simulator gateway URL: `http://localhost:30080/api/v1`
- Device gateway URL: `http://<YOUR_MAC_LAN_IP>:30080/api/v1`
  - Set via `TG_GATEWAY_BASE_URL_DEV_DEVICE`
  - In the shared scheme this variable is enabled by default; replace `YOUR_MAC_LAN_IP` before running on device.

## Production Kubernetes Mode (Private, Via Port-Forward)

Use scheme: `traders_guild Prod K8s`

- `TG_API_ROUTING_MODE=API_GATEWAY`
- Simulator gateway URL: `http://localhost:30081/api/v1`
- Device gateway URL: `http://<YOUR_MAC_LAN_IP>:30081/api/v1`
  - Set via `TG_GATEWAY_BASE_URL_DEV_DEVICE`

## Hetzner Remote Mode

Use scheme: `traders_guild Hetzner Remote`

- `TG_API_ROUTING_MODE=API_GATEWAY`
- Simulator gateway URL: `https://api-dev.tradersguild.co/api/v1`
- Device gateway URL: `https://api-dev.tradersguild.co/api/v1`
- No local port-forward is required

## Validation Commands (Platform Repo)

```bash
make argocd-apps-local    # Check local staging app sync/health
make smoke-staging-local  # Verify Kong routes + websocket + schema
make kong-local-port-forward-device MAC_LAN_IP=<your-mac-lan-ip>  # Expose local Kong for device on LAN
make kong-prod-port-forward  # Expose prod Kong for simulator at localhost:30081
make kong-prod-port-forward-device MAC_LAN_IP=<your-mac-lan-ip>  # Expose prod Kong for device
```

## Production-Like Validation

Production remains private/non-public. Use the same gateway mode behavior and validate backend/platform with smoke checks in the platform repo before iOS release work.
