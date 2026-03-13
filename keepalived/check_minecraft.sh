#!/usr/bin/env bash
# =============================================================================
# check_minecraft.sh – Keepalived health-check script
# =============================================================================
# Place on BOTH nodes at: /etc/keepalived/check_minecraft.sh
# Make executable: chmod +x /etc/keepalived/check_minecraft.sh
#
# Returns:
#   0 – Minecraft container is running and healthy  →  keep / take VIP
#   1 – Container is missing or unhealthy           →  release VIP
# =============================================================================
set -euo pipefail

CONTAINER_NAME="${MINECRAFT_CONTAINER:-minecraft-primary}"

# Check if container exists and is in a running/healthy state
STATUS=$(docker inspect --format='{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "missing")

case "${STATUS}" in
    running)
        # Also check Docker health if the image exposes it
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "none")
        if [[ "${HEALTH}" == "unhealthy" ]]; then
            exit 1
        fi
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
