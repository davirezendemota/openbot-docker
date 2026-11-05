# Setup

Step-by-step guides for running isolated OpenBot containers on a Linux host with Docker.

## Before you start

All stacks share the same **host firewall**. Install it once and list every Docker bridge you will use for OpenBot.

```bash
sudo install -d /etc/openbot-docker
sudo cp host/firewall.conf.example /etc/openbot-docker/firewall.conf
# Edit OPENBOT_FIREWALL_BRIDGES (space-separated bridge names)
# Optional: OPENBOT_FIREWALL_ALLOW_UDP only if you use the Tailscale stack (see below)
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

## Default installation (no Tailscale)

Start here. Root **`compose.yaml`** runs the pinned **upstream** OpenBot image with isolation defaults (bridge, seccomp, host firewall).

**Guide:** [docs/setup-generic.md](docs/setup-generic.md)

```bash
cp .env.example .env
docker compose up -d
docker compose exec openbot openbot login
```

## Optional: Tailscale inside the container

Add this **only if** you need a tailnet node, ACL-controlled access to `100.x` peers, or host UDP tuning for remote browser WebRTC.

**Guide:** [docs/setup-tailscale.md](docs/setup-tailscale.md)

```bash
cd stacks/tailscale
cp .env.example .env
# set OPENBOT_TAILSCALE_AUTHKEY, append br-openbot-ts to OPENBOT_FIREWALL_BRIDGES
docker compose up -d --build
```

You can run the default stack and the Tailscale stack on the same host (separate bridges/subnets/volumes) or use Tailscale alone.

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
