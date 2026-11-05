# openbot-docker

Public repository: Docker Compose + host firewall for **isolated self-hosted OpenBot** containers. Not tied to any other monorepo or deployment; clone and run on a Linux host with Docker.

**Installation:** [SETUP.md](SETUP.md) — default [docs/setup-generic.md](docs/setup-generic.md); optional [docs/setup-tailscale.md](docs/setup-tailscale.md).

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
[ tailnet optional — stacks/tailscale/ ]   [ container: OpenBot or tailscaled+OpenBot ]
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
| `compose.yaml` | Default upstream image; env `OPENBOT_BRIDGE_NAME`, `OPENBOT_IMAGE` |
| `stacks/tailscale/compose.yaml` | Optional Tailscale build; env `OPENBOT_TAILSCALE_AUTHKEY`, `TS_HOSTNAME` |
| `image/Dockerfile` | Used only by `stacks/tailscale/` — Tailscale binaries + upstream OpenBot |
| `image/entrypoint.sh` | Starts `tailscaled`, `tailscale up`, then `openbot-container` as UID `openbot` |
| `host/firewall.sh` | Idempotent iptables; config `/etc/openbot-docker/firewall.conf` or `host/firewall.conf` |
| `stacks/plain/` | Copy-paste template for an extra generic instance |

## Conventions

- **Bridge names** must match between Compose `com.docker.network.bridge.name` and `OPENBOT_FIREWALL_BRIDGES`.
- **Secrets:** only in `.env` (gitignored); never commit auth keys.
- **Upgrades:** bump digest in `.env`; for Tailscale stack rebuild `stacks/tailscale`; sync `seccomp.json` from upstream when needed.
- **Commits:** Conventional Commits in English; keep firewall and compose changes reviewable separately when possible.

## Agent workflow hints

- Prefer minimal diffs; do not add unrelated services to compose.
- When adding a new stack under `stacks/`, document unique bridge, subnet, volume name, and firewall line in that stack’s README.
- Do not weaken isolation (`privileged`, `seccomp=unconfined`, host bind mounts, `docker.sock`) unless the user explicitly accepts the risk in writing.
- Test suggestions: `docker compose config`, firewall `status`, optional curl probes from inside the container (see [SETUP.md](SETUP.md) and [README.md](README.md)).

## Links

- [SETUP.md](SETUP.md) — shared firewall prerequisites and links to setup guides
- [docs/setup-generic.md](docs/setup-generic.md) — default root stack
- [docs/setup-tailscale.md](docs/setup-tailscale.md) — optional `stacks/tailscale/`
- OpenBot upstream Docker docs: https://github.com/nightly-labs/openbot (`docs/docker.md`)
- [README.md](README.md) — layout, isolation model, upgrade, multi-instance checklist
