#!/usr/bin/env bash
# =============================================================================
# security-iptables.sh – Firewall hardening for GameServer nodes
# =============================================================================
# Run this script on BOTH Node A and Node B (as root / sudo).
#
# What it does:
#   1. Allows established/related connections (stateful firewall)
#   2. Allows SSH from anywhere (adjust the source if possible)
#   3. Allows Minecraft traffic (25565) ONLY from the Velocity proxy IP
#   4. Allows NFS traffic ONLY over the internal storage VLAN interface
#   5. Allows VRRP (Keepalived) multicast between the two nodes
#   6. Drops everything else
#
# Adjust the variables below before running.
# =============================================================================
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
PROXY_IP="192.168.1.20"          # IP of the Velocity proxy  (adjust!)
NODE_A_IP="192.168.1.10"         # IP of Node A              (adjust!)
NODE_B_IP="192.168.1.11"         # IP of Node B              (adjust!)
NFS_SERVER_IP="192.168.1.5"      # IP of NFS server          (adjust!)
INTERNAL_IFACE="eth1"            # NIC used for storage VLAN (adjust!)
PUBLIC_IFACE="eth0"              # NIC facing the internet   (adjust!)
MC_PORT="25565"
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

# ── Minecraft – only from Velocity proxy ─────────────────────────────────────
log "Restricting port ${MC_PORT} to Velocity proxy IP ${PROXY_IP}..."
iptables -A INPUT -p tcp --dport "${MC_PORT}" -s "${PROXY_IP}" -j ACCEPT
iptables -A INPUT -p tcp --dport "${MC_PORT}" -j DROP

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
# On Debian/Ubuntu you can also use:  apt-get install iptables-persistent
# And then:  netfilter-persistent save

log "Firewall rules applied successfully."
iptables -L INPUT -n --line-numbers
