#!/usr/bin/env bash
# =============================================================================
# setup-nfs-client.sh – Mount the shared NFS export on a game-server node
# =============================================================================
# Run this script on BOTH Node A and Node B before starting the containers.
#
# What it does:
#   1. Installs NFS client utilities
#   2. Creates the local mount point
#   3. Adds a persistent entry to /etc/fstab (IPv4 or IPv6 NFS server address)
#   4. Mounts the NFS share immediately
#
# Usage (as root or with sudo):
#   chmod +x setup-nfs-client.sh
#   sudo NFS_SERVER_IP=192.168.1.5 ./setup-nfs-client.sh        # IPv4
#   sudo NFS_SERVER_IP=fd00::5     ./setup-nfs-client.sh        # IPv6
#
# Required environment variable:
#   NFS_SERVER_IP   IP address (IPv4 or IPv6) of the NFS server
# =============================================================================
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
NFS_SERVER_IP="${NFS_SERVER_IP:?NFS_SERVER_IP must be set}"
NFS_EXPORT="/srv/gamedata"
LOCAL_MOUNT="/mnt/gamedata"
# Mount options:
#   hard      – retry NFS requests indefinitely (blocks instead of crashing)
#   intr      – allow signals (Ctrl-C) to interrupt stuck NFS operations
#   nfsvers=4 – NFSv4 (supports IPv6)
#   timeo=14  – client timeout (tenths of a second)
#   retrans=3 – retries before raising a major error
MOUNT_OPTIONS="hard,intr,nfsvers=4,timeo=14,retrans=3"
# ─────────────────────────────────────────────────────────────────────────────

log() { echo "[nfs-client] $*"; }

# Wrap bare IPv6 addresses in brackets for fstab / mount
# IPv6 addresses contain colons; IPv4 addresses do not.
if [[ "${NFS_SERVER_IP}" == *:* ]]; then
    NFS_SERVER_FSTAB="[${NFS_SERVER_IP}]"
    log "Detected IPv6 NFS server address: ${NFS_SERVER_IP}"
else
    NFS_SERVER_FSTAB="${NFS_SERVER_IP}"
    log "Detected IPv4 NFS server address: ${NFS_SERVER_IP}"
fi

# 1. Install NFS client
log "Installing NFS client utilities..."
apt-get update -qq
apt-get install -y nfs-common

# 2. Create mount point
log "Creating local mount point: ${LOCAL_MOUNT}"
mkdir -p "${LOCAL_MOUNT}"

# 3. Add to /etc/fstab for persistence across reboots
FSTAB_ENTRY="${NFS_SERVER_FSTAB}:${NFS_EXPORT}  ${LOCAL_MOUNT}  nfs  ${MOUNT_OPTIONS}  0  0"

if grep -qF "${NFS_EXPORT}  ${LOCAL_MOUNT}" /etc/fstab; then
    log "fstab entry already exists – skipping."
else
    log "Adding fstab entry: ${FSTAB_ENTRY}"
    echo "${FSTAB_ENTRY}" >> /etc/fstab
fi

# 4. Mount now
log "Mounting NFS share..."
mount "${LOCAL_MOUNT}" 2>/dev/null || mount -a

# 5. Verify
if mountpoint -q "${LOCAL_MOUNT}"; then
    log "NFS share mounted successfully at ${LOCAL_MOUNT}"
    df -h "${LOCAL_MOUNT}"
else
    echo "[nfs-client] ERROR: Failed to mount ${LOCAL_MOUNT}" >&2
    exit 1
fi

log "Done."
