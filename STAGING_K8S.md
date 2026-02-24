# iOS Staging Kubernetes Routing

Use the shared Xcode scheme `traders_guild Staging K8s` for gateway-based staging.

## Simulator
- `TG_API_ROUTING_MODE=API_GATEWAY`
- `TG_GATEWAY_BASE_URL_DEV=http://localhost:30080/api/v1`

## Physical Device
- Enable and set `TG_GATEWAY_BASE_URL_DEV_DEVICE=http://<YOUR_MAC_LAN_IP>:30080/api/v1`
- Keep `TG_API_ROUTING_MODE=API_GATEWAY`

## Compose direct-services mode
- Keep using the normal debug scheme with default `DIRECT_SERVICES` behavior.
