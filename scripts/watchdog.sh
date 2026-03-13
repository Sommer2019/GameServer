#!/usr/bin/env bash
# =============================================================================
# watchdog.sh – Session-Lock Monitor for Hot-Standby Node B
# =============================================================================
# This script runs inside the backup container.  It continuously checks
# whether the primary (Node A) still holds the Minecraft session.lock on the
# shared NFS storage.  Once the lock is gone (primary died / crashed), this
# node promotes itself and starts the Minecraft server process.
#
# Environment variables (can be passed via Docker Compose):
#   SESSION_LOCK_PATH   Path to session.lock on the shared NFS mount
#                       Default: /data/worlds/world/session.lock
#   CHECK_INTERVAL      Seconds between lock-checks while in standby
#                       Default: 5
#   LOCK_TIMEOUT        Seconds a stale lock must be absent before we start
#                       Default: 10
#   MINECRAFT_CMD       Command to start Minecraft (relative to /data)
#                       Default: /start (provided by itzg/minecraft-server)
# =============================================================================
set -euo pipefail

SESSION_LOCK_PATH="${SESSION_LOCK_PATH:-/data/worlds/world/session.lock}"
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"
LOCK_TIMEOUT="${LOCK_TIMEOUT:-10}"
MINECRAFT_CMD="${MINECRAFT_CMD:-/start}"

log() {
    echo "[watchdog] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

wait_for_lock_release() {
    local absent_count=0
    local needed_count=$(( LOCK_TIMEOUT / CHECK_INTERVAL ))
    [[ $needed_count -lt 1 ]] && needed_count=1

    log "Entering standby loop – monitoring ${SESSION_LOCK_PATH}"
    log "Will promote after ${needed_count} consecutive absent checks (${LOCK_TIMEOUT}s)"

    while true; do
        if [[ -f "${SESSION_LOCK_PATH}" ]]; then
            # Lock exists – primary is alive; reset counter
            if [[ $absent_count -gt 0 ]]; then
                log "Lock reappeared – primary recovered. Resetting counter."
            fi
            absent_count=0
        else
            absent_count=$(( absent_count + 1 ))
            log "Lock absent (${absent_count}/${needed_count})..."

            if [[ $absent_count -ge $needed_count ]]; then
                log "Lock absent for ${LOCK_TIMEOUT}s – promoting this node to ACTIVE."
                return 0
            fi
        fi
        sleep "${CHECK_INTERVAL}"
    done
}

promote() {
    log "=== NODE PROMOTION: Starting Minecraft server ==="
    # Signal healthcheck & other tools that we are now active
    touch /tmp/minecraft-active
    # shellcheck disable=SC2086  # intentional word-splitting for command + args
    exec ${MINECRAFT_CMD}
}

# ── Main ──────────────────────────────────────────────────────────────────────
log "Watchdog started on backup node."
log "Waiting for primary lock to disappear at: ${SESSION_LOCK_PATH}"

# Give NFS a moment to settle on container startup
sleep 3

wait_for_lock_release
promote
