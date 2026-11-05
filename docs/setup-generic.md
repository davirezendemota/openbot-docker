# Generic setup (upstream image)

Run OpenBot from the **official pinned image** with no Tailscale inside the container. Traffic uses outbound connections only (no published ports). This matches the upstream Docker model with this repo’s isolation extras: dedicated bridge, seccomp profile, capability drops, and host egress filtering.

Default stack: `stacks/plain/compose.yaml`.

## 1. Host firewall

Complete the shared steps in [SETUP.md](../SETUP.md#before-you-start).

For the plain stack example, set:

```bash
OPENBOT_FIREWALL_BRIDGES="br-openbot-1 br-openbot-2"
```

Include `br-openbot-1` if you also run the root Tailscale stack, and always include the bridge name from your plain stack `.env` (`OPENBOT_BRIDGE_NAME`, default `br-openbot-2`).

Reload after edits:

```bash
sudo systemctl restart openbot-firewall
sudo /usr/local/lib/openbot-docker/firewall.sh status
```

## 2. Environment

```bash
cd stacks/plain
cp .env.example .env
```

| Variable | Purpose |
|----------|---------|
| `OPENBOT_IMAGE` | Pinned `ghcr.io/nightly-labs/openbot` digest |
| `OPENBOT_CONTAINER_NAME` | Docker container name |
| `OPENBOT_HOSTNAME` | Hostname inside the container |
| `OPENBOT_BRIDGE_NAME` | Bridge interface on the host |
| `OPENBOT_VOLUME_NAME` | Explicit volume name for `/data` |
| `OPENBOT_MEM_LIMIT` / `OPENBOT_CPUS` | Resource limits |

Adjust the subnet in `compose.yaml` if you add more instances (each needs a non-overlapping `10.88.x.0/24`).

## 3. Start

```bash
docker compose up -d
docker compose exec openbot openbot login
```

Optional mobile QR:

```bash
docker compose exec openbot openbot mobile-connect
```

## 4. Verify

```bash
docker compose ps
docker compose exec -T openbot curl -sI -m5 https://openbot.run | head -1
docker compose exec -T openbot curl -s -m3 -o /dev/null -w "%{http_code}\n" http://10.88.1.1 || echo blocked
sudo journalctl -k -g openbot-drop --since -10min
```

Replace probe URLs with addresses on your LAN; they should fail or time out while public HTTPS succeeds.

## 5. Another generic instance

1. Copy `stacks/plain` to `stacks/<name>/`.
2. Change in `.env`: container name, hostname, bridge name, volume name.
3. Change in `compose.yaml`: `subnet` under `networks.isolated.ipam`.
4. Add the new bridge to `OPENBOT_FIREWALL_BRIDGES`.
5. `docker compose up -d` from the new directory and run `openbot login`.

Each instance is a separate Remote host in the OpenBot app with its own `/data` volume.

## 6. Generic vs Tailscale stack

| | Generic (`stacks/plain`) | Tailscale (root `compose.yaml`) |
|--|--------------------------|----------------------------------|
| Image | Upstream only | Custom build with `tailscaled` |
| Tailnet node | No | Yes (`TS_HOSTNAME`) |
| Extra caps | Minimal | Adds `NET_ADMIN`, `SYS_MODULE`, `/dev/net/tun` |
| Use case | Simple self-hosted host | ACL-controlled tailnet access, UDP tuning for remote UI |

See [setup-tailscale.md](setup-tailscale.md) for the Tailscale path.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Agent cannot reach internet | Host firewall not blocking public egress; DNS 1.1.1.1 reachable |
| Unexpected LAN access | Bridge missing from `OPENBOT_FIREWALL_BRIDGES`; run `firewall.sh status` |
| Login loops | Run `openbot login` inside the correct container name |
| Out of memory | Raise `OPENBOT_MEM_LIMIT` or reduce parallel agents |
