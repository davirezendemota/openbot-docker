#!/usr/bin/env bash
# tailscaled (root) then OpenBot (UID openbot). Requires OPENBOT_TAILSCALE_AUTHKEY.
set -euo pipefail

TS_STATE_DIR="${TS_STATE_DIR:-/var/lib/tailscale}"
TS_SOCKET="/var/run/tailscale/tailscaled.sock"
TS_AUTHKEY="${OPENBOT_TAILSCALE_AUTHKEY:-}"
TS_HOSTNAME="${TS_HOSTNAME:-openbot-node}"

if [[ -z "${TS_AUTHKEY}" ]]; then
  echo "OPENBOT_TAILSCALE_AUTHKEY is required" >&2
  exit 1
fi

mkdir -p "${TS_STATE_DIR}" /var/run/tailscale

tailscaled --state="${TS_STATE_DIR}/tailscaled.state" --socket="${TS_SOCKET}" &
ts_pid=$!
cleanup() { kill "${ts_pid}" 2>/dev/null || true; }
trap cleanup EXIT

for _ in $(seq 1 45); do
  if tailscale --socket="${TS_SOCKET}" status --json >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

tailscale --socket="${TS_SOCKET}" up \
  --authkey="${TS_AUTHKEY}" \
  --hostname="${TS_HOSTNAME}" \
  --accept-routes=false \
  --accept-dns=false

ts_backend_running() {
  tailscale --socket="${TS_SOCKET}" status --json 2>/dev/null \
    | grep -Eq '"BackendState"[[:space:]]*:[[:space:]]*"Running"'
}

for _ in $(seq 1 90); do
  if ts_backend_running; then
    break
  fi
  sleep 1
done

if ! ts_backend_running; then
  echo "tailscale did not reach Running state" >&2
  tailscale --socket="${TS_SOCKET}" status >&2 || true
  exit 1
fi

trap - EXIT

exec runuser -u openbot -- /usr/bin/tini -- bash -c \
  'exec /opt/OpenBot/app/resources/hosting/openbot-container 2> >(grep --line-buffered -vF '\''Received TURN CreatePermission error response, code=403'\'' >&2)'
