# Additional instance template

Copy this directory to a new name (e.g. `stacks/work/`) and adjust:

1. `.env` — unique `OPENBOT_CONTAINER_NAME`, `OPENBOT_HOSTNAME`, `OPENBOT_BRIDGE_NAME`, `OPENBOT_VOLUME_NAME`, subnet in `compose.yaml`.
2. `host/firewall.conf` — append the new bridge to `OPENBOT_FIREWALL_BRIDGES`, reload firewall.
3. Run from that directory: `docker compose up -d`.

Each instance is a separate Remote host in the OpenBot app (`openbot login` per container).

For Tailscale inside the container, use the root `compose.yaml` pattern (build from `image/`) once per instance with its own project directory and bridge name.
