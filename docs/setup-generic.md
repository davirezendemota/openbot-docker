# Generic setup (upstream image)

Default installation: **repository root** `compose.yaml`. No Tailscale, no custom image build — only the pinned upstream OpenBot image, isolated bridge, seccomp, and host egress filtering.

Tailscale is **optional**; see [setup-tailscale.md](setup-tailscale.md) if you need it later.

## 1. Host firewall

Complete the shared steps in [SETUP.md](../SETUP.md#before-you-start).

For the default stack, set:

```bash
OPENBOT_FIREWALL_BRIDGES="br-openbot-1"
```

Use the same name as `OPENBOT_BRIDGE_NAME` in `.env` (default `br-openbot-1`).

If you also run [stacks/plain](../stacks/plain/) or [stacks/tailscale](../stacks/tailscale/), append those bridges to the same list.

Reload after edits:

```bash
sudo systemctl restart openbot-firewall
sudo /usr/local/lib/openbot-docker/firewall.sh status
sudo /usr/local/lib/openbot-docker/firewall.sh check   # must print OK
```

## 2. Environment

From the repository root:

```bash
cp .env.example .env
```

| Variable | Purpose |
|----------|---------|
| `OPENBOT_IMAGE` | Pinned `ghcr.io/nightly-labs/openbot` digest |
| `OPENBOT_CONTAINER_NAME` | Docker container name |
| `OPENBOT_HOSTNAME` | Hostname inside the container |
| `OPENBOT_BRIDGE_NAME` | Bridge interface on the host |
| `OPENBOT_SUBNET` | Bridge subnet (default `10.88.0.0/24`); change if it overlaps your LAN |
| `OPENBOT_MEM_LIMIT` / `OPENBOT_CPUS` | Resource limits |

Never commit `.env`.

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
docker compose exec -T openbot curl -s -m3 -o /dev/null -w "%{http_code}\n" http://<LAN-or-gateway-IP> || echo blocked
sudo journalctl -k -g openbot-drop --since -10min
```

Replace probe URLs with addresses on your LAN; they should fail or time out while public HTTPS succeeds.

## 5. Another generic instance

1. Copy `stacks/plain` to `stacks/<name>/`.
2. Change in `.env`: container name, hostname, bridge name, volume name, subnet.
3. Set a unique `OPENBOT_SUBNET` in `.env` (default in `compose.yaml` is `10.88.1.0/24`).
4. Add the new bridge to `OPENBOT_FIREWALL_BRIDGES`.
5. `docker compose up -d` from the new directory and run `openbot login`.

Each instance is a separate Remote host in the OpenBot app with its own `/data` volume.

## 6. Optional Tailscale stack

| | Default (root) | Optional (`stacks/tailscale/`) |
|--|----------------|--------------------------------|
| Image | Upstream only | Custom build with `tailscaled` |
| Tailnet node | No | Yes (`TS_HOSTNAME`) |
| Extra caps | Minimal | Adds `NET_ADMIN`, `SYS_MODULE`, `/dev/net/tun` |
| When to add | — | Tailnet ACLs, direct UDP for remote UI over Tailscale |

See [setup-tailscale.md](setup-tailscale.md).

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Agent cannot reach internet | Host firewall not blocking public egress; DNS 1.1.1.1 reachable |
| Unexpected LAN access | Bridge missing from `OPENBOT_FIREWALL_BRIDGES`; run `firewall.sh status` |
| Login loops | Run `openbot login` inside the correct container name |
| Out of memory | Raise `OPENBOT_MEM_LIMIT` or reduce parallel agents |
