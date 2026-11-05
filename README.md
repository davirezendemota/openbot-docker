# openbot-docker

Docker Compose and host firewall recipes to run one or more **isolated** [OpenBot](https://openbot.run/) servers ([nightly-labs/openbot](https://github.com/nightly-labs/openbot)). Each container is the security boundary: full agent access inside, no host bind mounts, no published ports, dedicated bridge network with ICC disabled.

Upstream license: PolyForm Noncommercial 1.0.0 (personal use OK; commercial use requires a license from the OpenBot authors).

## Layout

| Path | Purpose |
|------|---------|
| `compose.yaml` | Primary stack: custom image (`image/`) with Tailscale + OpenBot |
| `image/` | Dockerfile and entrypoint (`tailscaled` then OpenBot as user `openbot`) |
| `seccomp.json` | OpenBot upstream seccomp profile (Electron sandbox) |
| `host/` | iptables egress filter for Docker bridge interfaces |
| `stacks/plain/` | Optional second instance using the upstream image only (no Tailscale) |

## Quick start (Tailscale stack)

1. Copy env and set a Tailscale auth key (tagged key matching your ACL):

```bash
cp .env.example .env
# edit OPENBOT_TAILSCALE_AUTHKEY, TS_HOSTNAME, OPENBOT_BRIDGE_NAME
```

2. Install host firewall (Linux, root). List every OpenBot bridge you will use:

```bash
sudo install -d /etc/openbot-docker
sudo cp host/firewall.conf.example /etc/openbot-docker/firewall.conf
# edit OPENBOT_FIREWALL_BRIDGES and optional OPENBOT_FIREWALL_ALLOW_UDP
sudo install -d /usr/local/lib/openbot-docker
sudo install -m 755 host/firewall.sh /usr/local/lib/openbot-docker/firewall.sh
sudo install -m 644 host/openbot-firewall.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now openbot-firewall
sudo /usr/local/lib/openbot-docker/firewall.sh status
```

3. Start OpenBot:

```bash
docker compose up -d --build
docker compose exec openbot tailscale status
docker compose exec openbot openbot login
```

The server appears in the OpenBot desktop or web app as a Remote host. Mobile pairing: `docker compose exec openbot openbot mobile-connect`.

## Plain upstream instance (no Tailscale)

```bash
cd stacks/plain
cp .env.example .env
docker compose up -d
docker compose exec openbot openbot login
```

Add `br-openbot-2` (or your bridge name) to `OPENBOT_FIREWALL_BRIDGES` before starting traffic.

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
docker compose exec -T openbot curl -s -m3 -o /dev/null -w "%{http_code}\n" http://10.88.0.1 || echo blocked
docker compose exec -T openbot curl -sI -m5 https://openbot.run | head -1
sudo journalctl -k -g openbot-drop --since -10min
```

## Upgrade OpenBot

OpenBot does not downgrade data. Back up the `openbot_data` volume before upgrading.

1. Pull new tag, verify attestation: `gh attestation verify oci://ghcr.io/nightly-labs/openbot@<digest> --repo nightly-labs/openbot`
2. Refresh `seccomp.json` from the same upstream tag if it changed.
3. Update `OPENBOT_IMAGE` in `.env`, `docker compose build --no-cache && docker compose up -d`.

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
