# Späterer Umstieg auf IPv6 / Dual-Stack

Dieses Testlab ist absichtlich **IPv4-only**. Wenn dein Test stabil läuft, kannst du in die Dual-Stack-Phase wechseln.

## Zielbild

Später verwendest du wieder die bestehenden Dual-Stack-Dateien im Repo:

- `docker-compose-node-a.yml`
- `docker-compose-node-b.yml`
- `keepalived/node-a/keepalived.conf`
- `keepalived/node-b/keepalived.conf`
- `velocity/velocity-node-a.toml`
- `velocity/velocity-node-b.toml`
- `scripts/setup-docker-ipv6.sh`
- `scripts/security-iptables.sh`

## Empfohlene Reihenfolge

### 1. Öffentliche oder intern geroutete IPv6-Adressen klären

Du brauchst später mindestens:

- `PROXY_VIP6`
- `NODE_A_IP6`
- `NODE_B_IP6`
- optional `NFS_SERVER_IP6`

## 2. Docker IPv6 auf PC 1 und PC 2 aktivieren

```bash
cd /opt/gameserver
chmod +x scripts/setup-docker-ipv6.sh
sudo bash scripts/setup-docker-ipv6.sh
```

## 3. Dual-Stack-Compose-Dateien verwenden

Ab dann nicht mehr die Test-Compose-Dateien nutzen, sondern:

```bash
docker compose -f docker-compose-node-a.yml --env-file .env up -d
docker compose -f docker-compose-node-b.yml --env-file .env up -d
```

## 4. Keepalived IPv6-VIP ergänzen

Dann die produktiven `keepalived.conf`-Dateien verwenden. Dort ist bereits vorgesehen:

- `PROXY_VIP6`
- `version 3`
- eigene VRRPv3-Instanz

## 5. Velocity Dual-Stack aktivieren

In den produktiven `velocity-node-*.toml` werden später wieder genutzt:

- `bind = "[::]:25577"`
- `main6`
- `backup6`
- `lobby6`

## 6. DNS erweitern

In der IPv4-Testphase nur A-Record.
Später zusätzlich:

- `AAAA` → auf die IPv6-VIP

## 7. Firewall dual-stack härten

Erst in der IPv6-Phase das produktive Firewall-Skript einsetzen:

```bash
cd /opt/gameserver
chmod +x scripts/security-iptables.sh
sudo bash scripts/security-iptables.sh
```

## Merksatz

- **jetzt:** nur Dateien in `test/ipv4-lab/` verwenden
- **später:** auf die produktiven Root-Dateien umsteigen

