#!/usr/bin/env bash
# =============================================================================
# security-iptables.sh – Firewall hardening for GameServer nodes
# =============================================================================
# Run this script on BOTH Node A and Node B (as root / sudo).
#
# Architecture (3 PCs):
#   PC 1 (Node A) – Minecraft Primary + Velocity Proxy 1 – 192.168.1.10
#   PC 2 (Node B) – Minecraft Backup  + Velocity Proxy 2 – 192.168.1.11
#   PC 3 (NFS)    – Dedicated storage (no game process)   – 192.168.1.5
#
# What this script does:
#   1. Allows established/related connections (stateful firewall)
#   2. Allows SSH from anywhere (restrict the source IP in production!)
#   3. Exposes the public Velocity port (25565) to the world (proxy is here)
#   4. Restricts the Minecraft backend port (25565 on 127.0.0.1) so ONLY the
#      local Velocity proxy can reach it (Docker binds to 127.0.0.1 already)
#   5. Allows NFS traffic ONLY over the internal storage VLAN interface
#   6. Allows VRRP (Keepalived) multicast between the two nodes
#   7. Drops everything else
#
# Adjust the variables below before running.
# =============================================================================
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
NODE_A_IP="192.168.1.10"         # IP of Node A              (adjust!)
NODE_B_IP="192.168.1.11"         # IP of Node B              (adjust!)
NFS_SERVER_IP="192.168.1.5"      # IP of dedicated NFS PC    (adjust!)
INTERNAL_IFACE="eth1"            # NIC used for storage VLAN (adjust!)
PUBLIC_IFACE="eth0"              # NIC facing the internet   (adjust!)
VELOCITY_PORT="25565"            # Public port players connect to
MC_BACKEND_PORT="25565"          # Minecraft backend (localhost-only binding)
NFS_PORT="2049"
# ─────────────────────────────────────────────────────────────────────────────

log() { echo "[iptables] $*"; }

# Save existing rules for reference
log "Saving current rules to /etc/iptables/rules.v4.bak"
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4.bak 2>/dev/null || true

# ── Flush existing rules ──────────────────────────────────────────────────────
log "Flushing existing rules..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# ── Default policies ──────────────────────────────────────────────────────────
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  ACCEPT

# ── Loopback ──────────────────────────────────────────────────────────────────
iptables -A INPUT -i lo -j ACCEPT

# ── Established / related connections ─────────────────────────────────────────
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ── SSH – allow from anywhere (restrict source IP in production!) ─────────────
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# ── Velocity proxy port – public, accept from anywhere ───────────────────────
# The Velocity container listens on 0.0.0.0:25565 and handles authentication.
log "Allowing public Velocity port ${VELOCITY_PORT}..."
iptables -A INPUT -p tcp --dport "${VELOCITY_PORT}" -j ACCEPT

# ── Minecraft backend – Docker binds to 127.0.0.1; block on all other IPs ────
# The Minecraft container's port is bound to 127.0.0.1 in docker-compose so
# external hosts cannot reach it directly. This rule is a belt-and-suspenders
# safeguard to drop any attempt on the external interface.
log "Blocking Minecraft backend port ${MC_BACKEND_PORT} on external interface..."
iptables -A INPUT -i "${PUBLIC_IFACE}" -p tcp --dport "${MC_BACKEND_PORT}" -j DROP

# ── NFS – only over internal storage interface ────────────────────────────────
log "Restricting NFS port ${NFS_PORT} to internal interface ${INTERNAL_IFACE}..."
iptables -A INPUT -i "${INTERNAL_IFACE}" -p tcp --dport "${NFS_PORT}" -s "${NFS_SERVER_IP}" -j ACCEPT
iptables -A INPUT -i "${INTERNAL_IFACE}" -p udp --dport "${NFS_PORT}" -s "${NFS_SERVER_IP}" -j ACCEPT
iptables -A INPUT -p tcp --dport "${NFS_PORT}" -j DROP

# ── Keepalived / VRRP (multicast 224.0.0.18, protocol 112) ───────────────────
log "Allowing VRRP multicast for Keepalived..."
iptables -A INPUT -p vrrp -j ACCEPT
iptables -A INPUT -d 224.0.0.18 -j ACCEPT
# Allow Keepalived unicast between the two nodes
iptables -A INPUT -s "${NODE_A_IP}" -j ACCEPT
iptables -A INPUT -s "${NODE_B_IP}" -j ACCEPT

# ── ICMP (ping) ───────────────────────────────────────────────────────────────
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# ── Persist rules ─────────────────────────────────────────────────────────────
log "Persisting iptables rules..."
if command -v iptables-save > /dev/null; then
    iptables-save > /etc/iptables/rules.v4
fi
# On Debian/Ubuntu you can also install iptables-persistent:
#   apt-get install iptables-persistent
#   netfilter-persistent save

log "Firewall rules applied successfully."
iptables -L INPUT -n --line-numbers
