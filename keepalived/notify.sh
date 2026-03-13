#!/usr/bin/env bash
# =============================================================================
# notify.sh – Keepalived state-change notification
# =============================================================================
# Place on BOTH nodes at: /etc/keepalived/notify.sh
# Make executable: chmod +x /etc/keepalived/notify.sh
#
# Called by keepalived with one argument: MASTER | BACKUP | FAULT
# =============================================================================
set -euo pipefail

STATE="${1:-UNKNOWN}"
LOG_FILE="/var/log/keepalived-notify.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

log() {
    echo "[keepalived-notify] ${TIMESTAMP} ${*}" | tee -a "${LOG_FILE}"
}

case "${STATE}" in
    MASTER)
        log "This node is now MASTER – holding the VIP."
        # No action needed; Docker and the watchdog handle the actual promotion.
        ;;
    BACKUP)
        log "This node is now BACKUP – VIP released to primary."
        ;;
    FAULT)
        log "Keepalived FAULT state detected on this node."
        ;;
    *)
        log "Unknown state: ${STATE}"
        ;;
esac
