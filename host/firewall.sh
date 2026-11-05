#!/usr/bin/env bash
# Host egress filter for OpenBot Docker bridge networks.
# Blocks container traffic to RFC1918, CGNAT tailnet range, link-local, and multicast.
# Public internet egress remains allowed (OpenBot account service, providers, TURN).
#
# Usage:
#   sudo ./host/firewall.sh [up|down|status|check]
#
# Configure bridges and optional UDP allowlist via host/firewall.conf (copy from firewall.conf.example)
# or environment variables OPENBOT_FIREWALL_BRIDGES / OPENBOT_FIREWALL_ALLOW_UDP.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${OPENBOT_FIREWALL_CONF:-${SCRIPT_DIR}/firewall.conf}"

if [[ -f "${CONF}" ]]; then
  # shellcheck source=/dev/null
  source "${CONF}"
fi

read -r -a BRIDGES <<< "${OPENBOT_FIREWALL_BRIDGES:-br-openbot-1}"
read -r -a ALLOW_UDP <<< "${OPENBOT_FIREWALL_ALLOW_UDP:-}"

BLOCK=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16 224.0.0.0/4 255.255.255.255/32)

ensure_jump() {
  iptables -C "$1" -i "$2" -j "$3" 2>/dev/null || iptables -I "$1" -i "$2" -j "$3"
}

up() {
  iptables -N DOCKER-USER 2>/dev/null || true
  for c in OPENBOT-DROP OPENBOT-EGRESS; do
    iptables -N "$c" 2>/dev/null || iptables -F "$c"
  done

  iptables -A OPENBOT-DROP -m addrtype --dst-type BROADCAST,MULTICAST -j DROP
  iptables -A OPENBOT-DROP -m limit --limit 6/min -j LOG --log-prefix "openbot-drop: "
  iptables -A OPENBOT-DROP -j DROP

  for ip in "${ALLOW_UDP[@]}"; do
    [[ -z "${ip}" ]] && continue
    iptables -A OPENBOT-EGRESS -d "$ip" -p udp -j RETURN
  done

  for net in "${BLOCK[@]}"; do
    iptables -A OPENBOT-EGRESS -d "$net" -j OPENBOT-DROP
  done

  for br in "${BRIDGES[@]}"; do
    [[ -z "${br}" ]] && continue
    ensure_jump INPUT "$br" OPENBOT-DROP
    ensure_jump DOCKER-USER "$br" OPENBOT-EGRESS
  done
}

down() {
  for br in "${BRIDGES[@]}"; do
    [[ -z "${br}" ]] && continue
    iptables -D INPUT -i "$br" -j OPENBOT-DROP 2>/dev/null || true
    iptables -D DOCKER-USER -i "$br" -j OPENBOT-EGRESS 2>/dev/null || true
  done
  for c in OPENBOT-EGRESS OPENBOT-DROP; do
    iptables -F "$c" 2>/dev/null || true
    iptables -X "$c" 2>/dev/null || true
  done
}

status() {
  for br in "${BRIDGES[@]}"; do
    [[ -z "${br}" ]] && continue
    iptables -S INPUT | grep -- "$br" || echo "INPUT: no rule for $br"
    iptables -S DOCKER-USER | grep -- "$br" || echo "DOCKER-USER: no rule for $br"
  done
  iptables -L OPENBOT-EGRESS -nv 2>/dev/null || true
  iptables -L OPENBOT-DROP -nv 2>/dev/null || true
}

# Exit non-zero if any configured bridge lacks its egress rules.
check() {
  local rc=0
  for br in "${BRIDGES[@]}"; do
    [[ -z "${br}" ]] && continue
    iptables -C INPUT -i "$br" -j OPENBOT-DROP 2>/dev/null || { echo "MISSING: INPUT rule for $br" >&2; rc=1; }
    iptables -C DOCKER-USER -i "$br" -j OPENBOT-EGRESS 2>/dev/null || { echo "MISSING: DOCKER-USER rule for $br" >&2; rc=1; }
  done
  [[ $rc -eq 0 ]] && echo "OK: firewall active for ${BRIDGES[*]}"
  return $rc
}

case "${1:-up}" in
  up) up ;;
  down) down ;;
  status) status ;;
  check) check ;;
  *) echo "usage: $0 [up|down|status|check]" >&2; exit 2 ;;
esac
