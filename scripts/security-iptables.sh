#!/usr/bin/env bash
# =============================================================================
# security-iptables.sh – Dual-stack firewall hardening for GameServer nodes
# =============================================================================
# Run this script on BOTH Node A and Node B (as root / sudo).
#
# Architecture (3 PCs, dual-stack IPv4 + IPv6):
#   PC 1 (Node A) – Minecraft Primary + Velocity Proxy 1 – 192.168.1.10 / fd00::10
#   PC 2 (Node B) – Minecraft Backup  + Velocity Proxy 2 – 192.168.1.11 / fd00::11
#   PC 3 (NFS)    – Dedicated storage (no game process)   – 192.168.1.5  / fd00::5
#
# What this script does (for BOTH iptables and ip6tables):
#   1. Allows established/related connections (stateful)
#   2. Allows SSH
#   3. Exposes the public Velocity port (25565) – proxy handles auth
#   4. Blocks the Minecraft backend port on the external interface
#      (Docker already binds it to 127.0.0.1 and ::1 only)
#   5. Allows NFS ports (2049 + portmapper 111) ONLY on the internal VLAN iface
#   6. Allows VRRP/VRRPv3 multicast for Keepalived
#   7. Allows required ICMPv6 types (neighbour discovery, etc.)
#   8. Drops everything else
# =============================================================================
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
# IPv4 addresses
NODE_A_IP="192.168.1.10"
NODE_B_IP="192.168.1.11"
NFS_SERVER_IP="192.168.1.5"

# IPv6 addresses
NODE_A_IP6="fd00::10"
NODE_B_IP6="fd00::11"
NFS_SERVER_IP6="fd00::5"

INTERNAL_IFACE="eth1"    # NIC used for storage VLAN (adjust!)
PUBLIC_IFACE="eth0"      # NIC facing the internet   (adjust!)
VELOCITY_PORT="25565"    # Public port players connect to
MC_BACKEND_PORT="25565"  # Minecraft backend (loopback-only binding)
NFS_PORT="2049"
PORTMAPPER_PORT="111"    # NFS portmapper / rpcbind
# ─────────────────────────────────────────────────────────────────────────────

log() { echo "[firewall] $*"; }

# ── Helpers ───────────────────────────────────────────────────────────────────
apply_v4() { iptables  "$@"; }
apply_v6() { ip6tables "$@"; }
apply_both() { iptables "$@"; ip6tables "$@"; }

# ── Save backups ──────────────────────────────────────────────────────────────
log "Saving current rules..."
mkdir -p /etc/iptables
iptables-save  > /etc/iptables/rules.v4.bak 2>/dev/null || true
ip6tables-save > /etc/iptables/rules.v6.bak 2>/dev/null || true

# ── Flush ─────────────────────────────────────────────────────────────────────
log "Flushing existing rules..."
apply_both -F
apply_both -X
apply_v4 -t nat -F
apply_v4 -t nat -X

# ── Default policies ──────────────────────────────────────────────────────────
apply_both -P INPUT   DROP
apply_both -P FORWARD DROP
apply_both -P OUTPUT  ACCEPT

# ── Loopback ──────────────────────────────────────────────────────────────────
apply_both -A INPUT -i lo -j ACCEPT

# ── Established / related ─────────────────────────────────────────────────────
apply_both -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ── SSH ───────────────────────────────────────────────────────────────────────
apply_both -A INPUT -p tcp --dport 22 -j ACCEPT

# ── Velocity proxy port (public) ──────────────────────────────────────────────
log "Opening public Velocity port ${VELOCITY_PORT} (IPv4 + IPv6)..."
apply_both -A INPUT -p tcp --dport "${VELOCITY_PORT}" -j ACCEPT

# ── Minecraft backend – block on external interface ───────────────────────────
# Belt-and-suspenders: Docker already binds to 127.0.0.1 and ::1, but this
# ensures packets arriving on the external NIC are dropped regardless.
log "Blocking Minecraft backend port ${MC_BACKEND_PORT} on external interface..."
apply_v4 -A INPUT -i "${PUBLIC_IFACE}" -p tcp --dport "${MC_BACKEND_PORT}" -j DROP
apply_v6 -A INPUT -i "${PUBLIC_IFACE}" -p tcp --dport "${MC_BACKEND_PORT}" -j DROP

# ── NFS – only over internal storage interface ────────────────────────────────
# Accept NFS (2049) and portmapper (111) from the NFS server only, on the
# internal VLAN interface. Drop both ports on any other interface.
log "Restricting NFS/portmapper to internal interface ${INTERNAL_IFACE}..."

for PORT in "${NFS_PORT}" "${PORTMAPPER_PORT}"; do
    # IPv4
    apply_v4 -A INPUT -i "${INTERNAL_IFACE}" -p tcp --dport "${PORT}" -s "${NFS_SERVER_IP}"  -j ACCEPT
    apply_v4 -A INPUT -i "${INTERNAL_IFACE}" -p udp --dport "${PORT}" -s "${NFS_SERVER_IP}"  -j ACCEPT
    apply_v4 -A INPUT                         -p tcp --dport "${PORT}" -j DROP
    apply_v4 -A INPUT                         -p udp --dport "${PORT}" -j DROP
    # IPv6
    apply_v6 -A INPUT -i "${INTERNAL_IFACE}" -p tcp --dport "${PORT}" -s "${NFS_SERVER_IP6}" -j ACCEPT
    apply_v6 -A INPUT -i "${INTERNAL_IFACE}" -p udp --dport "${PORT}" -s "${NFS_SERVER_IP6}" -j ACCEPT
    apply_v6 -A INPUT                         -p tcp --dport "${PORT}" -j DROP
    apply_v6 -A INPUT                         -p udp --dport "${PORT}" -j DROP
done

# ── Keepalived – VRRP (IPv4, multicast 224.0.0.18, proto 112) ─────────────────
log "Allowing VRRPv2 multicast (IPv4)..."
apply_v4 -A INPUT -p 112 -j ACCEPT
apply_v4 -A INPUT -d 224.0.0.18 -j ACCEPT
# Keepalived unicast between the two nodes
apply_v4 -A INPUT -s "${NODE_A_IP}" -j ACCEPT
apply_v4 -A INPUT -s "${NODE_B_IP}" -j ACCEPT

# ── Keepalived – VRRPv3 (IPv6, multicast ff02::12, proto 112) ─────────────────
log "Allowing VRRPv3 multicast (IPv6)..."
apply_v6 -A INPUT -p 112 -j ACCEPT
apply_v6 -A INPUT -d ff02::12 -j ACCEPT
apply_v6 -A INPUT -s "${NODE_A_IP6}" -j ACCEPT
apply_v6 -A INPUT -s "${NODE_B_IP6}" -j ACCEPT

# ── ICMP (ping) – IPv4 ────────────────────────────────────────────────────────
apply_v4 -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# ── ICMPv6 – required for IPv6 to function ────────────────────────────────────
# Without these, IPv6 neighbour discovery (NDP), router advertisements, and
# path MTU discovery all break.
log "Allowing essential ICMPv6 types..."
for TYPE in \
    echo-request \
    destination-unreachable \
    packet-too-big \
    time-exceeded \
    router-solicitation \
    router-advertisement \
    neighbour-solicitation \
    neighbour-advertisement
do
    apply_v6 -A INPUT  -p icmpv6 --icmpv6-type "${TYPE}" -j ACCEPT
    apply_v6 -A OUTPUT -p icmpv6 --icmpv6-type "${TYPE}" -j ACCEPT
done

# ── Persist rules ─────────────────────────────────────────────────────────────
log "Persisting rules..."
iptables-save  > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
# On Debian/Ubuntu: apt-get install iptables-persistent && netfilter-persistent save

log "Done. Current INPUT chain (IPv4):"
iptables  -L INPUT -n --line-numbers
log "Current INPUT chain (IPv6):"
ip6tables -L INPUT -n --line-numbers
