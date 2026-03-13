#!/usr/bin/env bash
# =============================================================================
# check_minecraft.sh – Keepalived health-check for Minecraft backend
# =============================================================================
# Place on BOTH nodes at: /etc/keepalived/check_minecraft.sh
# Make executable: chmod +x /etc/keepalived/check_minecraft.sh
#
# Returns:
#   0 – Minecraft container is running and healthy  →  keep / take VIP
#   1 – Container is missing or unhealthy           →  reduce priority
#
# The script auto-detects whether this is Node A (minecraft-primary) or
# Node B (minecraft-backup) by checking for each container name.
# =============================================================================
set -euo pipefail

# Detect local container name
if docker inspect minecraft-primary > /dev/null 2>&1; then
    CONTAINER_NAME="minecraft-primary"
elif docker inspect minecraft-backup > /dev/null 2>&1; then
    CONTAINER_NAME="minecraft-backup"
else
    # Neither container exists on this host
    exit 1
fi

STATUS=$(docker inspect --format='{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "missing")

case "${STATUS}" in
    running)
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
