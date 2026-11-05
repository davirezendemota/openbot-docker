# Setup

Step-by-step guides for running isolated OpenBot containers on a Linux host with Docker.

## Before you start

Both paths share the same **host firewall**. Install it once and list every Docker bridge you will use for OpenBot stacks.

```bash
sudo install -d /etc/openbot-docker
sudo cp host/firewall.conf.example /etc/openbot-docker/firewall.conf
# Edit OPENBOT_FIREWALL_BRIDGES (space-separated bridge names)
# Optional: OPENBOT_FIREWALL_ALLOW_UDP for Tailscale WebRTC (see Tailscale guide)
sudo install -d /usr/local/lib/openbot-docker
sudo install -m 755 host/firewall.sh /usr/local/lib/openbot-docker/firewall.sh
sudo install -m 644 host/openbot-firewall.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now openbot-firewall
sudo /usr/local/lib/openbot-docker/firewall.sh status
```

Requirements:

- Linux with Docker Engine and Compose v2
- Enough RAM for OpenBot (several GiB per active agent; set `OPENBOT_MEM_LIMIT` in `.env`)
- Outbound internet from the container (account service, providers, TURN)

## Choose a setup path

| Guide | When to use |
|-------|-------------|
| [docs/setup-tailscale.md](docs/setup-tailscale.md) | Remote browser over Tailscale, tailnet ACLs, or UDP allowlist for low-latency WebRTC |
| [docs/setup-generic.md](docs/setup-generic.md) | Standard upstream OpenBot image only; no Tailscale inside the container |

Root `compose.yaml` implements the Tailscale path. The generic path uses `stacks/plain/compose.yaml` (copy the directory to add more instances).

## After installation

- Log in from the container: `docker compose exec openbot openbot login`
- Validate egress and isolation: [README.md](README.md#validate-egress)
- Upgrade pinned images: [README.md](README.md#upgrade-openbot)
- Multiple instances: [README.md](README.md#multiple-instances-checklist)

## Teardown

```bash
docker compose stop
sudo systemctl disable --now openbot-firewall   # optional
```

Named volumes keep `/data` until you remove them explicitly.
