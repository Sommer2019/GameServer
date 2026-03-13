#!/usr/bin/env bash
# =============================================================================
# test/test_infrastructure.sh – Validation tests for GameServer HA infrastructure
# =============================================================================
# Tests file existence, bash syntax, watchdog logic, and config contents.
#
# Run with:
#   bash test/test_infrastructure.sh
# =============================================================================
set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── Helpers ───────────────────────────────────────────────────────────────────
assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "  PASS: ${desc}"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: ${desc}"
        echo "        Expected : '${expected}'"
        echo "        Actual   : '${actual}'"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_file() {
    local desc="$1" file="$2"
    if [[ -f "${file}" ]]; then
        echo "  PASS: ${desc}"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: ${desc} – not found: ${file}"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_no_file() {
    local desc="$1" file="$2"
    if [[ ! -f "${file}" ]]; then
        echo "  PASS: ${desc}"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: ${desc} – should not exist: ${file}"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_syntax() {
    local desc="$1" file="$2"
    if bash -n "${file}" 2>/dev/null; then
        echo "  PASS: ${desc}"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: ${desc} – syntax error in: ${file}"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_contains() {
    local desc="$1" file="$2" pattern="$3"
    if grep -q "${pattern}" "${file}" 2>/dev/null; then
        echo "  PASS: ${desc}"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: ${desc} – pattern '${pattern}' not found in ${file}"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_not_contains() {
    local desc="$1" file="$2" pattern="$3"
    if ! grep -q "${pattern}" "${file}" 2>/dev/null; then
        echo "  PASS: ${desc}"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: ${desc} – unexpected pattern '${pattern}' found in ${file}"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ── 1. File existence ─────────────────────────────────────────────────────────
echo "=== GameServer HA Infrastructure Tests ==="
echo ""
echo "-- 1. File existence --"

assert_file "docker-compose-node-a.yml"        "${REPO_ROOT}/docker-compose-node-a.yml"
assert_file "docker-compose-node-b.yml"        "${REPO_ROOT}/docker-compose-node-b.yml"
assert_no_file "standalone velocity compose removed" "${REPO_ROOT}/docker-compose-velocity.yml"
assert_file "keepalived/node-a/keepalived.conf"     "${REPO_ROOT}/keepalived/node-a/keepalived.conf"
assert_file "keepalived/node-b/keepalived.conf"     "${REPO_ROOT}/keepalived/node-b/keepalived.conf"
assert_file "keepalived/check_minecraft.sh"         "${REPO_ROOT}/keepalived/check_minecraft.sh"
assert_file "keepalived/check_velocity.sh"          "${REPO_ROOT}/keepalived/check_velocity.sh"
assert_file "keepalived/notify.sh"                  "${REPO_ROOT}/keepalived/notify.sh"
assert_file "nfs/setup-nfs-server.sh"               "${REPO_ROOT}/nfs/setup-nfs-server.sh"
assert_file "nfs/setup-nfs-client.sh"               "${REPO_ROOT}/nfs/setup-nfs-client.sh"
assert_file "nfs/exports"                           "${REPO_ROOT}/nfs/exports"
assert_file "velocity/velocity-node-a.toml"         "${REPO_ROOT}/velocity/velocity-node-a.toml"
assert_file "velocity/velocity-node-b.toml"         "${REPO_ROOT}/velocity/velocity-node-b.toml"
assert_no_file "shared velocity.toml removed"       "${REPO_ROOT}/velocity/velocity.toml"
assert_file "velocity/Dockerfile"                   "${REPO_ROOT}/velocity/Dockerfile"
assert_file "scripts/watchdog.sh"                   "${REPO_ROOT}/scripts/watchdog.sh"
assert_file "scripts/entrypoint-backup.sh"          "${REPO_ROOT}/scripts/entrypoint-backup.sh"
assert_file "scripts/security-iptables.sh"          "${REPO_ROOT}/scripts/security-iptables.sh"
assert_file "scripts/setup-docker-ipv6.sh"          "${REPO_ROOT}/scripts/setup-docker-ipv6.sh"
assert_file ".env.example"                          "${REPO_ROOT}/.env.example"
assert_file "README.md"                             "${REPO_ROOT}/README.md"

# ── 2. Bash syntax ────────────────────────────────────────────────────────────
echo ""
echo "-- 2. Bash syntax --"

assert_syntax "watchdog.sh"            "${REPO_ROOT}/scripts/watchdog.sh"
assert_syntax "entrypoint-backup.sh"   "${REPO_ROOT}/scripts/entrypoint-backup.sh"
assert_syntax "security-iptables.sh"   "${REPO_ROOT}/scripts/security-iptables.sh"
assert_syntax "setup-docker-ipv6.sh"   "${REPO_ROOT}/scripts/setup-docker-ipv6.sh"
assert_syntax "setup-nfs-server.sh"    "${REPO_ROOT}/nfs/setup-nfs-server.sh"
assert_syntax "setup-nfs-client.sh"    "${REPO_ROOT}/nfs/setup-nfs-client.sh"
assert_syntax "check_minecraft.sh"     "${REPO_ROOT}/keepalived/check_minecraft.sh"
assert_syntax "check_velocity.sh"      "${REPO_ROOT}/keepalived/check_velocity.sh"
assert_syntax "notify.sh"              "${REPO_ROOT}/keepalived/notify.sh"

# ── 3. Docker Compose: dual-service + dual-stack layout ──────────────────────
echo ""
echo "-- 3. Docker Compose: dual-service + dual-stack layout --"

NODE_A="${REPO_ROOT}/docker-compose-node-a.yml"
NODE_B="${REPO_ROOT}/docker-compose-node-b.yml"

assert_contains "Node A has minecraft-primary service"  "${NODE_A}" "minecraft-primary"
assert_contains "Node A has velocity-proxy-1 service"   "${NODE_A}" "velocity-proxy-1"
assert_contains "Node B has minecraft-backup service"   "${NODE_B}" "minecraft-backup"
assert_contains "Node B has velocity-proxy-2 service"   "${NODE_B}" "velocity-proxy-2"

# Minecraft backend: loopback only (IPv4 + IPv6)
assert_contains "Node A MC binds to 127.0.0.1"  "${NODE_A}" "127.0.0.1:25565"
assert_contains "Node A MC binds to ::1"         "${NODE_A}" '::1\]:25565:25565'
assert_contains "Node B MC binds to 127.0.0.1"  "${NODE_B}" "127.0.0.1:25565"
assert_contains "Node B MC binds to ::1"         "${NODE_B}" '::1\]:25565:25565'

# Velocity proxy: public ports on both IPv4 and IPv6
assert_contains "Node A Velocity IPv4 public port"  "${NODE_A}" '"0.0.0.0:25565:25577"'
assert_contains "Node A Velocity IPv6 public port"  "${NODE_A}" '::\]:25565:25577'
assert_contains "Node B Velocity IPv4 public port"  "${NODE_B}" '"0.0.0.0:25565:25577"'
assert_contains "Node B Velocity IPv6 public port"  "${NODE_B}" '::\]:25565:25577'

# IPv6 enabled on docker network
assert_contains "Node A network enable_ipv6"  "${NODE_A}" "enable_ipv6: true"
assert_contains "Node B network enable_ipv6"  "${NODE_B}" "enable_ipv6: true"

# IPv6 subnet defined in both compose files
assert_contains "Node A has IPv6 subnet fd20"  "${NODE_A}" "fd20::/64"
assert_contains "Node B has IPv6 subnet fd21"  "${NODE_B}" "fd21::/64"

# Node A and B use DISTINCT IPv4 subnets
assert_contains "Node A IPv4 subnet 172.20"  "${NODE_A}" "172.20.0.0/24"
assert_contains "Node B IPv4 subnet 172.21"  "${NODE_B}" "172.21.0.0/24"
assert_not_contains "Node B does not use Node A subnet" "${NODE_B}" "172.20.0.0/24"

# Node B must use the custom backup entrypoint
assert_contains "Node B uses entrypoint-backup.sh"  "${NODE_B}" "entrypoint-backup.sh"

# NFS worlds mount present on both
assert_contains "Node A mounts NFS worlds" "${NODE_A}" "/mnt/gamedata/worlds"
assert_contains "Node B mounts NFS worlds" "${NODE_B}" "/mnt/gamedata/worlds"

# Per-node velocity configs are mounted
assert_contains "Node A mounts velocity-node-a.toml" "${NODE_A}" "velocity-node-a.toml"
assert_contains "Node B mounts velocity-node-b.toml" "${NODE_B}" "velocity-node-b.toml"

# ── 4. Keepalived: VRRP roles, priorities, and dual-stack VIPs ───────────────
echo ""
echo "-- 4. Keepalived configuration (dual-stack) --"

KA="${REPO_ROOT}/keepalived/node-a/keepalived.conf"
KB="${REPO_ROOT}/keepalived/node-b/keepalived.conf"

assert_contains "Node A state is MASTER"       "${KA}" "state  MASTER"
assert_contains "Node B state is BACKUP"       "${KB}" "state  BACKUP"
assert_contains "Node A priority 110"          "${KA}" "priority 110"
assert_contains "Node B priority 100"          "${KB}" "priority 100"
assert_contains "Both share virtual_router_id 51 (IPv4)" "${KA}" "virtual_router_id 51"
assert_contains "Both share virtual_router_id 51 (IPv4)" "${KB}" "virtual_router_id 51"
assert_contains "Both share virtual_router_id 52 (IPv6)" "${KA}" "virtual_router_id 52"
assert_contains "Both share virtual_router_id 52 (IPv6)" "${KB}" "virtual_router_id 52"
assert_contains "Node A tracks velocity"       "${KA}" "chk_velocity"
assert_contains "Node B tracks velocity"       "${KB}" "chk_velocity"
assert_contains "Node A tracks minecraft"      "${KA}" "chk_minecraft"
assert_contains "Node B tracks minecraft"      "${KB}" "chk_minecraft"

# IPv4 VIP
assert_contains "Node A uses IPv4 proxy VIP .200"   "${KA}" "192.168.1.200"
assert_contains "Node B uses IPv4 proxy VIP .200"   "${KB}" "192.168.1.200"

# IPv6 VIP
assert_contains "Node A uses IPv6 proxy VIP fd00::200" "${KA}" "fd00::200"
assert_contains "Node B uses IPv6 proxy VIP fd00::200" "${KB}" "fd00::200"

# VRRPv3 required for IPv6 instance
assert_contains "Node A IPv6 instance is PROXY_VIP6"  "${KA}" "PROXY_VIP6"
assert_contains "Node B IPv6 instance is PROXY_VIP6"  "${KB}" "PROXY_VIP6"
assert_contains "Node A IPv6 uses version 3"          "${KA}" "version 3"
assert_contains "Node B IPv6 uses version 3"          "${KB}" "version 3"

# ── 5. check_velocity.sh: auto-detects container name ─────────────────────────
echo ""
echo "-- 5. check_velocity.sh auto-detection --"

assert_contains "check_velocity detects proxy-1" \
    "${REPO_ROOT}/keepalived/check_velocity.sh" "velocity-proxy-1"
assert_contains "check_velocity detects proxy-2" \
    "${REPO_ROOT}/keepalived/check_velocity.sh" "velocity-proxy-2"
assert_contains "check_velocity probes TCP port" \
    "${REPO_ROOT}/keepalived/check_velocity.sh" "nc -z"

# ── 6. check_minecraft.sh: auto-detects container name ────────────────────────
echo ""
echo "-- 6. check_minecraft.sh auto-detection --"

assert_contains "check_minecraft detects primary" \
    "${REPO_ROOT}/keepalived/check_minecraft.sh" "minecraft-primary"
assert_contains "check_minecraft detects backup" \
    "${REPO_ROOT}/keepalived/check_minecraft.sh" "minecraft-backup"

# ── 7. velocity configs: per-node, dual-stack ────────────────────────────────
echo ""
echo "-- 7. velocity configs (per-node, dual-stack) --"

VNA="${REPO_ROOT}/velocity/velocity-node-a.toml"
VNB="${REPO_ROOT}/velocity/velocity-node-b.toml"

for VT in "${VNA}" "${VNB}"; do
    label="$(basename "${VT}")"
    assert_contains "${label} has [servers]"          "${VT}" '\[servers\]'
    assert_contains "${label} has main server"        "${VT}" 'main'
    assert_contains "${label} has backup server"      "${VT}" 'backup'
    assert_contains "${label} has try list"           "${VT}" 'try'
    assert_contains "${label} has [forced-hosts]"     "${VT}" '\[forced-hosts\]'
    assert_contains "${label} uses MODERN fwd"        "${VT}" 'MODERN'
    assert_contains "${label} has forwarding_secret"  "${VT}" 'forwarding_secret'
    # Dual-stack bind: [::] accepts both IPv4 and IPv6
    assert_contains "${label} binds to [::]"          "${VT}" '\[::\]:25577'
    # Co-located backend: both IPv4 and IPv6 loopback
    assert_contains "${label} has IPv4 loopback main" "${VT}" '127.0.0.1:25565'
    assert_contains "${label} has IPv6 loopback main" "${VT}" '\[::1\]:25565'
done

# Node A should fall back to Node B
assert_contains "velocity-node-a backup = Node B IPv4" "${VNA}" "192.168.1.11:25565"
assert_contains "velocity-node-a backup = Node B IPv6" "${VNA}" "fd00::11"

# Node B should fall back to Node A
assert_contains "velocity-node-b backup = Node A IPv4" "${VNB}" "192.168.1.10:25565"
assert_contains "velocity-node-b backup = Node A IPv6" "${VNB}" "fd00::10"

# ── 8. .env.example keys ─────────────────────────────────────────────────────
echo ""
echo "-- 8. .env.example (IPv4 + IPv6) --"

ENV="${REPO_ROOT}/.env.example"
for key in VELOCITY_SECRET PROXY_VIP PROXY_VIP6 NODE_A_IP NODE_A_IP6 NODE_B_IP NODE_B_IP6 NFS_SERVER_IP NFS_SERVER_IP6 KEEPALIVED_AUTH_PASS; do
    if grep -q "^${key}=" "${ENV}"; then
        echo "  PASS: .env.example has ${key}"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: .env.example missing ${key}"
        FAIL=$(( FAIL + 1 ))
    fi
done

assert_not_contains ".env.example has no plain VIP key" "${ENV}" "^VIP="

# ── 9. .gitignore excludes secrets ───────────────────────────────────────────
echo ""
echo "-- 9. .gitignore --"
assert_contains ".gitignore excludes .env" "${REPO_ROOT}/.gitignore" '^\.env$'

# ── 10. security-iptables.sh: dual-stack firewall ────────────────────────────
echo ""
echo "-- 10. Firewall: dual-stack (iptables + ip6tables) --"

FW="${REPO_ROOT}/scripts/security-iptables.sh"

assert_contains "firewall uses ip6tables"              "${FW}" "ip6tables"
assert_contains "firewall has NODE_A_IP6"              "${FW}" 'NODE_A_IP6'
assert_contains "firewall has NODE_B_IP6"              "${FW}" 'NODE_B_IP6'
assert_contains "firewall has NFS_SERVER_IP6"          "${FW}" 'NFS_SERVER_IP6'
assert_contains "firewall saves rules.v6"              "${FW}" "rules.v6"
assert_contains "firewall allows VRRPv3 multicast"     "${FW}" "ff02::12"
assert_contains "firewall locks NFS portmapper 111"    "${FW}" "PORTMAPPER_PORT"
assert_contains "firewall allows ICMPv6"               "${FW}" "icmpv6"
assert_contains "firewall allows neighbour-solicitation" "${FW}" "neighbour-solicitation"
assert_contains "firewall allows neighbour-advertisement" "${FW}" "neighbour-advertisement"
assert_contains "firewall applies IPv6 NFS drop"       "${FW}" "apply_v6"

# ── 11. NFS: IPv6 exports and client support ──────────────────────────────────
echo ""
echo "-- 11. NFS: dual-stack support --"

assert_contains "exports has IPv6 Node A"     "${REPO_ROOT}/nfs/exports"           "\[fd00::10\]"
assert_contains "exports has IPv6 Node B"     "${REPO_ROOT}/nfs/exports"           "\[fd00::11\]"
assert_contains "nfs-server has NODE_A_IP6"   "${REPO_ROOT}/nfs/setup-nfs-server.sh" 'NODE_A_IP6'
assert_contains "nfs-server has NODE_B_IP6"   "${REPO_ROOT}/nfs/setup-nfs-server.sh" 'NODE_B_IP6'
assert_contains "nfs-server brackets IPv6 in exports" "${REPO_ROOT}/nfs/setup-nfs-server.sh" '\[.*IP6'
assert_contains "nfs-client detects IPv6 address"     "${REPO_ROOT}/nfs/setup-nfs-client.sh" 'NFS_SERVER_FSTAB'
assert_contains "nfs-client brackets IPv6 for fstab"  "${REPO_ROOT}/nfs/setup-nfs-client.sh" '\[.*NFS_SERVER_IP'

# ── 12. setup-docker-ipv6.sh ──────────────────────────────────────────────────
echo ""
echo "-- 12. setup-docker-ipv6.sh --"

DV6="${REPO_ROOT}/scripts/setup-docker-ipv6.sh"
assert_contains "docker-ipv6 enables ipv6"      "${DV6}" '"ipv6": true'
assert_contains "docker-ipv6 sets fixed-cidr-v6" "${DV6}" 'fixed-cidr-v6'
assert_contains "docker-ipv6 enables ip6tables"  "${DV6}" '"ip6tables": true'
assert_contains "docker-ipv6 restarts daemon"    "${DV6}" "systemctl restart docker"

# ── 13. Watchdog functional logic ────────────────────────────────────────────
echo ""
echo "-- 13. Watchdog functional logic --"

WATCHDOG="${REPO_ROOT}/scripts/watchdog.sh"
TMPDIR_TEST="$(mktemp -d)"
WORLD_DIR="${TMPDIR_TEST}/world"
LOCK_FILE="${WORLD_DIR}/session.lock"
mkdir -p "${WORLD_DIR}"

# Test A: Lock absent from start → promote after timeout
rm -f "${LOCK_FILE}"
result=$(
    SESSION_LOCK_PATH="${LOCK_FILE}" \
    CHECK_INTERVAL=1 \
    LOCK_TIMEOUT=2 \
    MINECRAFT_CMD="echo PROMOTED" \
    timeout 10 bash "${WATCHDOG}" 2>/dev/null | tail -1 || true
)
assert_eq "Watchdog: lock absent → promotes" "PROMOTED" "${result}"

# Test B: Lock present then removed → promote after timeout (race-safe: sleep 2, LOCK_TIMEOUT=3)
touch "${LOCK_FILE}"
( sleep 2; rm -f "${LOCK_FILE}" ) &
result=$(
    SESSION_LOCK_PATH="${LOCK_FILE}" \
    CHECK_INTERVAL=1 \
    LOCK_TIMEOUT=3 \
    MINECRAFT_CMD="echo PROMOTED_AFTER_FAILOVER" \
    timeout 20 bash "${WATCHDOG}" 2>/dev/null | tail -1 || true
)
assert_eq "Watchdog: lock removed mid-run → promotes" "PROMOTED_AFTER_FAILOVER" "${result}"

rm -rf "${TMPDIR_TEST}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "============================================"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
