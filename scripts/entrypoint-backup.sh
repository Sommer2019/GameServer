#!/usr/bin/env bash
# =============================================================================
# entrypoint-backup.sh – Entrypoint for the Hot-Standby Container (Node B)
# =============================================================================
# Replaces the default itzg/minecraft-server entrypoint on the backup node.
# It starts the watchdog loop; once the primary is confirmed dead, it hands
# control to the normal server startup (/start).
# =============================================================================
set -euo pipefail

echo "[entrypoint-backup] Backup node starting in STANDBY mode."
echo "[entrypoint-backup] Minecraft will NOT start until the primary releases its lock."

# Ensure the watchdog script is executable
chmod +x /usr/local/bin/watchdog.sh

# Run the watchdog; it will exec /start when promotion happens
exec /usr/local/bin/watchdog.sh
