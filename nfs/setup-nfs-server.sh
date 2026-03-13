#!/usr/bin/env bash
# =============================================================================
# setup-nfs-server.sh – Configure the NFS server for shared game data
# =============================================================================
# Run this script ONCE on the machine that will serve the shared storage.
# This can be a dedicated NAS, one of the game-server nodes, or a separate VM.
#
# What it does:
#   1. Installs the NFS kernel server
#   2. Creates the export directory
#   3. Writes /etc/exports
#   4. Applies strict permissions
#   5. Starts / reloads the NFS service
#
# Usage (as root or with sudo):
#   chmod +x setup-nfs-server.sh
#   sudo ./setup-nfs-server.sh
#
# Adjust the variables below before running.
# =============================================================================
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
EXPORT_DIR="/srv/gamedata"               # Directory to export over NFS
NODE_A_IP="192.168.1.10"                 # IP of Node A (adjust!)
NODE_B_IP="192.168.1.11"                 # IP of Node B (adjust!)
# NFS export options:
#   rw           – read/write access
#   sync         – write to disk before acknowledging client (data safety)
#   no_subtree_check – improves reliability when exporting subdirectories
#   no_root_squash   – allow root on clients to act as root (needed by Docker)
EXPORT_OPTIONS="rw,sync,no_subtree_check,no_root_squash"
# ─────────────────────────────────────────────────────────────────────────────

log() { echo "[nfs-server] $*"; }

# 1. Install NFS server
log "Installing NFS kernel server..."
apt-get update -qq
apt-get install -y nfs-kernel-server

# 2. Create export directory with sub-directories
log "Creating export directory: ${EXPORT_DIR}"
mkdir -p "${EXPORT_DIR}/worlds"

# 3. Set permissions (root owns the directory; Docker containers run as root)
chown -R root:root "${EXPORT_DIR}"
chmod 755 "${EXPORT_DIR}"

# 4. Write /etc/exports
log "Writing /etc/exports..."
# Remove any stale entries for this path, then append new ones
sed -i "\|^${EXPORT_DIR}|d" /etc/exports

cat >> /etc/exports << EOF
# GameServer shared world data – managed by setup-nfs-server.sh
${EXPORT_DIR}  ${NODE_A_IP}(${EXPORT_OPTIONS})  ${NODE_B_IP}(${EXPORT_OPTIONS})
EOF

# 5. Export and restart
log "Exporting filesystems..."
exportfs -rav

log "Restarting NFS server..."
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server

log "NFS server ready. Exports:"
exportfs -v
log "Done."
