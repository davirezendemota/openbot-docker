# Setup with Tailscale (optional)

**Optional add-on.** Complete the [generic setup](setup-generic.md) first unless you only want Tailscale (you can skip the root stack and run this directory alone).

This stack builds a custom image that starts **tailscaled** inside the container, then OpenBot. The node registers on your tailnet with the hostname you set in `.env`. Use it when you want Tailscale ACLs to govern what the agent can reach on `100.x` peers, or when tuning remote browser latency with selective UDP egress on the host.

Stack: `stacks/tailscale/compose.yaml`, `image/Dockerfile`, `image/entrypoint.sh`.

## 1. Tailscale admin

1. In the [Tailscale admin console](https://login.tailscale.com/admin/acls), define ACL tags and rules for OpenBot nodes (example tag name: `tag:openbot` — use your own naming).
2. Create an **auth key** with that tag. Prefer **non-reusable** keys for production; note expiry.
3. Decide the machine hostname (`TS_HOSTNAME` in `.env`). It must be unique on the tailnet.

The container calls `tailscale up` with `--accept-routes=false` and `--accept-dns=false` so the host’s LAN DNS and routes are not pulled into the container.

## 2. Host firewall

Complete the shared steps in [SETUP.md](../SETUP.md#before-you-start).

Add the Tailscale stack bridge (default `br-openbot-ts`) to `/etc/openbot-docker/firewall.conf`:

```bash
OPENBOT_FIREWALL_BRIDGES="br-openbot-1 br-openbot-ts"
```

Include `br-openbot-1` only if you also run the root generic stack. Match `OPENBOT_BRIDGE_NAME` in `stacks/tailscale/.env`.

### Optional: faster remote browser over Tailscale

If the OpenBot app on a Tailscale client connects slowly (traffic relayed via OpenBot TURN), add the client’s Tailscale address to **UDP** allowlist on the host:

```bash
OPENBOT_FIREWALL_ALLOW_UDP="100.x.y.z/32"
```

Reload:

```bash
sudo systemctl restart openbot-firewall
```

Only add IPs you trust. TCP to tailnet peers stays blocked by the bridge egress rules; this exception is UDP-only for WebRTC.

## 3. Environment

```bash
cd stacks/tailscale
cp .env.example .env
```

| Variable | Purpose |
|----------|---------|
| `OPENBOT_TAILSCALE_AUTHKEY` | Auth key from step 1 (required) |
| `TS_HOSTNAME` | Tailscale node name |
| `OPENBOT_BRIDGE_NAME` | Docker bridge (`br-openbot-ts`) |
| `OPENBOT_IMAGE` | Pinned upstream OpenBot image digest (build arg) |
| `OPENBOT_TAILSCALE_IMAGE` | Pinned Tailscale image digest |
| `OPENBOT_MEM_LIMIT` / `OPENBOT_CPUS` | Resource limits |

Never commit `.env`.

## 4. Build and start

```bash
docker compose up -d --build
docker compose exec openbot tailscale status
docker compose exec openbot openbot login
```

The host appears in the OpenBot app as a Remote server. Rename it in the app if needed.

Mobile pairing (one-time QR, ~2 minutes):

```bash
docker compose exec openbot openbot mobile-connect
```

## 5. Providers

Connect Claude Code, Codex, or other providers from the OpenBot app. Credentials live in the container keyring under `/data`. Optional provider API keys can be passed via container environment only if you intentionally add them to compose (not enabled by default in this repo).

## 6. Verify Tailscale and isolation

```bash
docker compose exec openbot tailscale status
docker compose exec openbot tailscale ping <another-tailnet-node>   # if ACL allows
```

Egress checks (adjust LAN/tailnet URLs to your environment):

```bash
docker compose exec -T openbot curl -s -m3 -o /dev/null -w "%{http_code}\n" http://192.168.0.1 || echo blocked
docker compose exec -T openbot curl -sI -m5 https://openbot.run | head -1
sudo journalctl -k -g openbot-drop --since -10min
```

## 7. Second Tailscale instance

Copy `stacks/tailscale` to a new directory, then assign:

- New `TS_HOSTNAME`, bridge name, subnet in `compose.yaml`
- New `COMPOSE_PROJECT_NAME` in `.env`
- Append the new bridge to `OPENBOT_FIREWALL_BRIDGES`

Run `openbot login` again for the new container.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Container exits on start | `OPENBOT_TAILSCALE_AUTHKEY` set; key valid and tagged |
| `tailscale did not reach Running` | `docker compose logs openbot`; `/dev/net/tun` available on host |
| Slow remote UI | Add client Tailscale IP to `OPENBOT_FIREWALL_ALLOW_UDP` |
| Cannot reach a tailnet service | Tailscale **ACL** for this node’s tag, not only host firewall |
