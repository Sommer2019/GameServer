#!/usr/bin/env bash
# =============================================================================
# setup-nfs-server.sh – Configure the NFS server for shared game data
# =============================================================================
# Run this script ONCE on the dedicated NFS machine (PC 3).
#
# What it does:
#   1. Installs the NFS kernel server
#   2. Creates the export directory
#   3. Writes /etc/exports with both IPv4 and IPv6 client addresses
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
EXPORT_DIR="/srv/gamedata"

# IPv4 addresses of the game-server nodes
NODE_A_IP="172.29.80.10"
NODE_B_IP="172.29.80.11"

# IPv6 addresses of the game-server nodes (ULA; adjust to match your prefix)
NODE_A_IP6="fd00::10"
NODE_B_IP6="fd00::11"

# NFS export options:
#   rw               – read/write
#   sync             – write to disk before acknowledging client (data safety)
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

# 3. Set permissions
chown -R root:root "${EXPORT_DIR}"
chmod 755 "${EXPORT_DIR}"

# 4. Write /etc/exports
log "Writing /etc/exports (IPv4 + IPv6)..."
sed -i "\|^${EXPORT_DIR}|d" /etc/exports

cat >> /etc/exports << EOF
# GameServer shared world data – managed by setup-nfs-server.sh
# IPv4 clients
${EXPORT_DIR}  ${NODE_A_IP}(${EXPORT_OPTIONS})  ${NODE_B_IP}(${EXPORT_OPTIONS})  [${NODE_A_IP6}](${EXPORT_OPTIONS})  [${NODE_B_IP6}](${EXPORT_OPTIONS})
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
