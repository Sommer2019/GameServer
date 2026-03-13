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

assert_file "docker-compose-node-a.yml"   "${REPO_ROOT}/docker-compose-node-a.yml"
assert_file "docker-compose-node-b.yml"   "${REPO_ROOT}/docker-compose-node-b.yml"
assert_no_file "standalone velocity compose removed" "${REPO_ROOT}/docker-compose-velocity.yml"
assert_file "keepalived/node-a/keepalived.conf" "${REPO_ROOT}/keepalived/node-a/keepalived.conf"
assert_file "keepalived/node-b/keepalived.conf" "${REPO_ROOT}/keepalived/node-b/keepalived.conf"
assert_file "keepalived/check_minecraft.sh"     "${REPO_ROOT}/keepalived/check_minecraft.sh"
assert_file "keepalived/check_velocity.sh"      "${REPO_ROOT}/keepalived/check_velocity.sh"
assert_file "keepalived/notify.sh"              "${REPO_ROOT}/keepalived/notify.sh"
assert_file "nfs/setup-nfs-server.sh"           "${REPO_ROOT}/nfs/setup-nfs-server.sh"
assert_file "nfs/setup-nfs-client.sh"           "${REPO_ROOT}/nfs/setup-nfs-client.sh"
assert_file "nfs/exports"                       "${REPO_ROOT}/nfs/exports"
assert_file "velocity/velocity.toml"            "${REPO_ROOT}/velocity/velocity.toml"
assert_file "velocity/Dockerfile"               "${REPO_ROOT}/velocity/Dockerfile"
assert_file "scripts/watchdog.sh"               "${REPO_ROOT}/scripts/watchdog.sh"
assert_file "scripts/entrypoint-backup.sh"      "${REPO_ROOT}/scripts/entrypoint-backup.sh"
assert_file "scripts/security-iptables.sh"      "${REPO_ROOT}/scripts/security-iptables.sh"
assert_file ".env.example"                      "${REPO_ROOT}/.env.example"
assert_file "README.md"                         "${REPO_ROOT}/README.md"

# ── 2. Bash syntax ────────────────────────────────────────────────────────────
echo ""
echo "-- 2. Bash syntax --"

assert_syntax "watchdog.sh"          "${REPO_ROOT}/scripts/watchdog.sh"
assert_syntax "entrypoint-backup.sh" "${REPO_ROOT}/scripts/entrypoint-backup.sh"
assert_syntax "security-iptables.sh" "${REPO_ROOT}/scripts/security-iptables.sh"
assert_syntax "setup-nfs-server.sh"  "${REPO_ROOT}/nfs/setup-nfs-server.sh"
assert_syntax "setup-nfs-client.sh"  "${REPO_ROOT}/nfs/setup-nfs-client.sh"
assert_syntax "check_minecraft.sh"   "${REPO_ROOT}/keepalived/check_minecraft.sh"
assert_syntax "check_velocity.sh"    "${REPO_ROOT}/keepalived/check_velocity.sh"
assert_syntax "notify.sh"            "${REPO_ROOT}/keepalived/notify.sh"

# ── 3. Docker Compose: dual-service layout ───────────────────────────────────
echo ""
echo "-- 3. Docker Compose: dual-service layout --"

NODE_A="${REPO_ROOT}/docker-compose-node-a.yml"
NODE_B="${REPO_ROOT}/docker-compose-node-b.yml"

assert_contains "Node A has minecraft-primary service"  "${NODE_A}" "minecraft-primary"
assert_contains "Node A has velocity-proxy-1 service"   "${NODE_A}" "velocity-proxy-1"
assert_contains "Node B has minecraft-backup service"   "${NODE_B}" "minecraft-backup"
assert_contains "Node B has velocity-proxy-2 service"   "${NODE_B}" "velocity-proxy-2"

# Minecraft backend must bind only to localhost (not 0.0.0.0)
assert_contains "Node A MC binds to 127.0.0.1" "${NODE_A}" "127.0.0.1:25565"
assert_contains "Node B MC binds to 127.0.0.1" "${NODE_B}" "127.0.0.1:25565"

# Velocity proxy must expose on 0.0.0.0 (public port)
assert_contains "Node A Velocity exposes public port"  "${NODE_A}" '"25565:25577"'
assert_contains "Node B Velocity exposes public port"  "${NODE_B}" '"25565:25577"'

# Node B must use the custom backup entrypoint
assert_contains "Node B uses entrypoint-backup.sh"  "${NODE_B}" "entrypoint-backup.sh"

# NFS worlds mount present on both
assert_contains "Node A mounts NFS worlds" "${NODE_A}" "/mnt/gamedata/worlds"
assert_contains "Node B mounts NFS worlds" "${NODE_B}" "/mnt/gamedata/worlds"

# ── 4. Keepalived: VRRP roles and priorities ─────────────────────────────────
echo ""
echo "-- 4. Keepalived configuration --"

KA="${REPO_ROOT}/keepalived/node-a/keepalived.conf"
KB="${REPO_ROOT}/keepalived/node-b/keepalived.conf"

assert_contains "Node A state is MASTER"       "${KA}" "state  MASTER"
assert_contains "Node B state is BACKUP"       "${KB}" "state  BACKUP"
assert_contains "Node A priority 110"          "${KA}" "priority 110"
assert_contains "Node B priority 100"          "${KB}" "priority 100"
assert_contains "Both share virtual_router_id" "${KA}" "virtual_router_id 51"
assert_contains "Both share virtual_router_id" "${KB}" "virtual_router_id 51"
assert_contains "Node A tracks velocity"       "${KA}" "chk_velocity"
assert_contains "Node B tracks velocity"       "${KB}" "chk_velocity"
assert_contains "Node A tracks minecraft"      "${KA}" "chk_minecraft"
assert_contains "Node B tracks minecraft"      "${KB}" "chk_minecraft"
# VIP should be the proxy VIP (200), not the old 100
assert_contains "Node A uses proxy VIP .200"   "${KA}" "192.168.1.200"
assert_contains "Node B uses proxy VIP .200"   "${KB}" "192.168.1.200"
# VRRP instance name should reflect proxy role
assert_contains "Node A instance is PROXY_VIP" "${KA}" "PROXY_VIP"
assert_contains "Node B instance is PROXY_VIP" "${KB}" "PROXY_VIP"

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

# ── 7. velocity.toml content ─────────────────────────────────────────────────
echo ""
echo "-- 7. velocity.toml --"

VT="${REPO_ROOT}/velocity/velocity.toml"
assert_contains "velocity.toml has [servers]"       "${VT}" '\[servers\]'
assert_contains "velocity.toml has main server"     "${VT}" 'main'
assert_contains "velocity.toml has backup server"   "${VT}" 'backup'
assert_contains "velocity.toml has try list"        "${VT}" 'try'
assert_contains "velocity.toml has [forced-hosts]"  "${VT}" '\[forced-hosts\]'
assert_contains "velocity.toml uses MODERN fwd"     "${VT}" 'MODERN'
assert_contains "velocity.toml has forwarding_secret" "${VT}" 'forwarding_secret'
# Co-located backend should use localhost
assert_contains "velocity.toml uses localhost backend" "${VT}" '127.0.0.1:25565'

# ── 8. .env.example keys ─────────────────────────────────────────────────────
echo ""
echo "-- 8. .env.example --"

ENV="${REPO_ROOT}/.env.example"
for key in VELOCITY_SECRET PROXY_VIP NODE_A_IP NODE_B_IP NFS_SERVER_IP KEEPALIVED_AUTH_PASS; do
    if grep -q "^${key}=" "${ENV}"; then
        echo "  PASS: .env.example has ${key}"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: .env.example missing ${key}"
        FAIL=$(( FAIL + 1 ))
    fi
done

# Old standalone VIP key should be gone
assert_not_contains ".env.example has no plain VIP key" "${ENV}" "^VIP="

# ── 9. .gitignore excludes secrets ───────────────────────────────────────────
echo ""
echo "-- 9. .gitignore --"
assert_contains ".gitignore excludes .env" "${REPO_ROOT}/.gitignore" '^\.env$'

# ── 10. Watchdog functional logic ────────────────────────────────────────────
echo ""
echo "-- 10. Watchdog functional logic --"

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

# Test B: Lock present then removed → promote after timeout
touch "${LOCK_FILE}"
( sleep 2; rm -f "${LOCK_FILE}" ) &
result=$(
    SESSION_LOCK_PATH="${LOCK_FILE}" \
    CHECK_INTERVAL=1 \
    LOCK_TIMEOUT=2 \
    MINECRAFT_CMD="echo PROMOTED_AFTER_FAILOVER" \
    timeout 15 bash "${WATCHDOG}" 2>/dev/null | tail -1 || true
)
assert_eq "Watchdog: lock removed mid-run → promotes" "PROMOTED_AFTER_FAILOVER" "${result}"

rm -rf "${TMPDIR_TEST}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "============================================"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
