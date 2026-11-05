# openbot-docker

Public repository: Docker Compose + host firewall for **isolated self-hosted OpenBot** containers. Not tied to any other monorepo or deployment; clone and run on a Linux host with Docker.

## What this repo is

- **Goal:** Run OpenBot Remote hosts where the container is the trust boundary (upstream model).
- **Deliverables:** Pinned upstream image builds, optional Tailscale inside the container, iptables rules on the host for bridge egress, seccomp profile, templates for a second plain instance.
- **Out of scope:** Backup jobs, observability stacks, app-specific ACL files, or compose services unrelated to OpenBot.

## Architecture (one instance)

```text
[ OpenBot app ] ----internet----> [ OpenBot cloud / TURN ]
        |                                    ^
        | WebRTC / account                   |
        v                                    |
[ tailnet optional ]                  [ container ]
        |                             tailscaled + OpenBot
        |                             volume: /data
        v
[ host: docker bridge br-openbot-N ]
        |
        v
[ host/firewall.sh: DOCKER-USER + INPUT ]
        -> block RFC1918 / 100.64.0.0/10 / multicast from bridge
        -> allow public egress
```

## Key files

| File | Notes |
|------|--------|
| `compose.yaml` | Tailscale-enabled build; env `OPENBOT_TAILSCALE_AUTHKEY`, `TS_HOSTNAME`, `OPENBOT_BRIDGE_NAME` |
| `image/Dockerfile` | Multi-stage: copy `tailscale`/`tailscaled` into upstream OpenBot image |
| `image/entrypoint.sh` | Starts `tailscaled`, `tailscale up`, then `openbot-container` as UID `openbot` |
| `host/firewall.sh` | Idempotent iptables; config `/etc/openbot-docker/firewall.conf` or `host/firewall.conf` |
| `stacks/plain/` | Separate compose project: upstream image only, different subnet/bridge |

## Conventions

- **Bridge names** must match between Compose `com.docker.network.bridge.name` and `OPENBOT_FIREWALL_BRIDGES`.
- **Secrets:** only in `.env` (gitignored); never commit auth keys.
- **Upgrades:** bump digest in `.env`, sync `seccomp.json` from upstream when needed, rebuild image stack.
- **Commits:** Conventional Commits in English; keep firewall and compose changes reviewable separately when possible.

## Agent workflow hints

- Prefer minimal diffs; do not add unrelated services to compose.
- When adding a new stack under `stacks/`, document unique bridge, subnet, volume name, and firewall line in that stack’s README.
- Do not weaken isolation (`privileged`, `seccomp=unconfined`, host bind mounts, `docker.sock`) unless the user explicitly accepts the risk in writing.
- Test suggestions: `docker compose config`, firewall `status`, optional curl probes from inside the container (see root README).

## Links

- OpenBot upstream Docker docs: https://github.com/nightly-labs/openbot (`docs/docker.md`)
- This repo README: installation, validation, multi-instance checklist
