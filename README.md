<p align="center">
  <a href="https://openbot.run"><img src="docs/assets/openbot.png" alt="OpenBot" width="88" height="88" align="middle"></a>
  &nbsp;&nbsp;<strong>×</strong>&nbsp;&nbsp;
  <a href="https://www.docker.com/"><img src="docs/assets/docker.svg" alt="Docker" width="88" height="88" align="middle"></a>
</p>

# openbot-docker

Docker Compose and host firewall recipes to run one or more **isolated** [OpenBot](https://openbot.run/) servers ([nightly-labs/openbot](https://github.com/nightly-labs/openbot)). Each container is the security boundary: full agent access inside, no host bind mounts, no published ports, dedicated bridge network with ICC disabled.

This repository is licensed under [MIT](LICENSE). The upstream OpenBot image is a separate work under PolyForm Noncommercial 1.0.0 (personal use OK; commercial use requires a license from the OpenBot authors).

## Quick start

Requires a **Linux** host (iptables) with Docker Engine + Compose v2. Docker Desktop (macOS/Windows) cannot enforce the host firewall, so isolation would be incomplete.

```bash
# 1. Host firewall (once) — see SETUP.md for the full steps
sudo install -d /etc/openbot-docker /usr/local/lib/openbot-docker
sudo cp host/firewall.conf.example /etc/openbot-docker/firewall.conf
sudo install -m 755 host/firewall.sh /usr/local/lib/openbot-docker/firewall.sh
sudo install -m 644 host/openbot-firewall.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now openbot-firewall

# 2. Start OpenBot
cp .env.example .env
docker compose up -d
docker compose exec openbot openbot login

# 3. Confirm isolation is active
sudo /usr/local/lib/openbot-docker/firewall.sh check
```

Do not skip step 1: without it the container can reach your LAN.

## Layout

| Path | Purpose |
|------|---------|
| `compose.yaml` | **Default** stack: upstream OpenBot image (no Tailscale) |
| `stacks/tailscale/` | **Optional** custom image with Tailscale + OpenBot |
| `image/` | Dockerfile and entrypoint for the Tailscale stack only |
| `seccomp.json` | OpenBot upstream seccomp profile (Electron sandbox) |
| `host/` | iptables egress filter for Docker bridge interfaces |
| `stacks/plain/` | Template for a second generic instance (different bridge/subnet) |
| `SETUP.md` | Setup entry point (host firewall + default vs optional Tailscale) |
| `docs/setup-generic.md` | Default installation at repo root |
| `docs/setup-tailscale.md` | Optional Tailscale stack |

## Setup

Follow **[SETUP.md](SETUP.md)**:

1. **[docs/setup-generic.md](docs/setup-generic.md)** — default (`cp .env.example .env` → `docker compose up -d`)
2. **[docs/setup-tailscale.md](docs/setup-tailscale.md)** — optional (`stacks/tailscale/`)

## Isolation model

| Layer | Mechanism |
|-------|-----------|
| Container | No `-p`, no host paths, only named volumes (`/data`, Tailscale state) |
| Network | Private bridge, `enable_icc: false`, public DNS only |
| Process | `cap_drop: ALL`, minimal caps, `no-new-privileges`, pinned seccomp |
| Resources | `mem_limit`, `cpus`, `pids_limit` via env |
| Host | `host/firewall.sh` drops egress from bridge to RFC1918, CGNAT (`100.64.0.0/10`), link-local, multicast |

Agents on the **same** container share `/data` (providers, keyring, default browser partition). Separate accounts or blast radius → run **another** stack with its own volume and bridge.

### Remote browser latency (Tailscale)

If the OpenBot app on a Tailscale client is slow (TURN relay), you may add that client’s Tailscale `/32` to `OPENBOT_FIREWALL_ALLOW_UDP` so **UDP** WebRTC can flow directly. TCP to tailnet peers remains blocked by the host firewall; restrict allowed IPs deliberately.

## Validate egress

Replace probe URLs with addresses on your LAN or tailnet:

```bash
docker compose exec -T openbot curl -s -m3 -o /dev/null -w "%{http_code}\n" http://<LAN-or-gateway-IP> || echo blocked
docker compose exec -T openbot curl -sI -m5 https://openbot.run | head -1
sudo journalctl -k -g openbot-drop --since -10min
```

## Upgrade OpenBot

OpenBot does not downgrade data. Back up the `openbot_data` volume before upgrading.

1. Pull new tag, verify attestation: `gh attestation verify oci://ghcr.io/nightly-labs/openbot@<digest> --repo nightly-labs/openbot`
2. Refresh `seccomp.json` from the same upstream tag if it changed.
3. Update `OPENBOT_IMAGE` in `.env`, then `docker compose up -d` (root) or `docker compose build --no-cache && docker compose up -d` in `stacks/tailscale/` if you use Tailscale.

## Multiple instances checklist

- Unique `container_name`, volume, bridge name (`OPENBOT_BRIDGE_NAME`), and IP subnet per stack
- All bridges listed in `OPENBOT_FIREWALL_BRIDGES`
- Separate `openbot login` and Remote host name in the app
- Plan RAM: ~several GiB per active agent turn; sum limits across instances

## Stop and remove

```bash
docker compose stop
sudo systemctl disable --now openbot-firewall   # optional
```

Removing the container does not erase `/data`; delete the named volume only if you intend to wipe keys and workspaces.
