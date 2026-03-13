#!/usr/bin/env bash
# =============================================================================
# check_velocity.sh – Keepalived health-check for Velocity Proxy
# =============================================================================
# Place on BOTH nodes at: /etc/keepalived/check_velocity.sh
# Make executable: chmod +x /etc/keepalived/check_velocity.sh
#
# Returns:
#   0 – Velocity container is running and accepting connections  →  keep VIP
#   1 – Container is down or not listening                       →  reduce priority
#
# The script auto-detects Node A (velocity-proxy-1) or Node B (velocity-proxy-2).
# =============================================================================
set -euo pipefail

VELOCITY_PORT="${VELOCITY_PORT:-25577}"

# Detect local container name
if docker inspect velocity-proxy-1 > /dev/null 2>&1; then
    CONTAINER_NAME="velocity-proxy-1"
elif docker inspect velocity-proxy-2 > /dev/null 2>&1; then
    CONTAINER_NAME="velocity-proxy-2"
else
    exit 1
fi

# 1. Container must be in "running" state
STATUS=$(docker inspect --format='{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "missing")
if [[ "${STATUS}" != "running" ]]; then
    exit 1
fi

# 2. Proxy port must be accepting TCP connections
if ! nc -z -w 3 127.0.0.1 "${VELOCITY_PORT}" 2>/dev/null; then
    exit 1
fi

exit 0
