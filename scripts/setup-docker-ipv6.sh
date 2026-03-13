#!/usr/bin/env bash
# =============================================================================
# setup-docker-ipv6.sh – Enable IPv6 support in the Docker daemon
# =============================================================================
# Run this script on BOTH Node A and Node B before starting any containers.
#
# What it does:
#   1. Writes (or merges) /etc/docker/daemon.json to enable IPv6
#   2. Assigns a ULA prefix to Docker's default bridge (docker0)
#   3. Enables IPv6 NAT for outbound container traffic (ip6tables)
#   4. Restarts the Docker daemon
#
# Why this is needed:
#   Docker does NOT enable IPv6 by default. Without this configuration,
#   `enable_ipv6: true` in docker-compose files will be silently ignored
#   or will fail with "IPv6 not available".
#
# The docker-compose files use CUSTOM networks with their own IPv6 subnets
#   (fd20::/64 on Node A, fd21::/64 on Node B).
# The fixed-cidr-v6 here is only for the default docker0 bridge.
#
# Usage (as root or with sudo):
#   chmod +x setup-docker-ipv6.sh
#   sudo ./setup-docker-ipv6.sh
#
# Adjust the variable below if needed.
# =============================================================================
set -euo pipefail

# ULA prefix for the default docker0 bridge.
# Custom compose networks use fd20::/64 (Node A) and fd21::/64 (Node B).
DOCKER_IPV6_CIDR="fd00:d0c::/64"

DAEMON_JSON="/etc/docker/daemon.json"

log() { echo "[docker-ipv6] $*"; }

# ── Ensure jq is available for JSON merging ───────────────────────────────────
if ! command -v jq > /dev/null 2>&1; then
    log "Installing jq..."
    apt-get update -qq && apt-get install -y jq
fi

# ── Create or merge daemon.json ───────────────────────────────────────────────
mkdir -p /etc/docker

if [[ -f "${DAEMON_JSON}" ]]; then
    log "Merging IPv6 settings into existing ${DAEMON_JSON}..."
    EXISTING=$(cat "${DAEMON_JSON}")
    UPDATED=$(echo "${EXISTING}" | jq \
        --arg cidr "${DOCKER_IPV6_CIDR}" \
        '. + {"ipv6": true, "fixed-cidr-v6": $cidr, "ip6tables": true}')
    echo "${UPDATED}" > "${DAEMON_JSON}"
else
    log "Creating ${DAEMON_JSON} with IPv6 settings..."
    cat > "${DAEMON_JSON}" << EOF
{
  "ipv6": true,
  "fixed-cidr-v6": "${DOCKER_IPV6_CIDR}",
  "ip6tables": true
}
EOF
fi

log "Written ${DAEMON_JSON}:"
cat "${DAEMON_JSON}"

# ── Restart Docker daemon ─────────────────────────────────────────────────────
log "Restarting Docker daemon..."
systemctl restart docker

# ── Verify ────────────────────────────────────────────────────────────────────
log "Verifying Docker IPv6 support..."
if docker network inspect bridge | grep -q '"EnableIPv6": true'; then
    log "SUCCESS: Docker IPv6 is active on the default bridge."
else
    log "WARNING: Default bridge does not show IPv6 yet."
    log "         This is normal for custom compose networks – proceed with:"
    log "           docker compose -f docker-compose-node-X.yml up -d"
    log "         and verify with: docker network inspect gameserver-net"
fi

log "Done."
