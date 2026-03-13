# IPv4-Testlab für das HA-Setup

Dieses Verzeichnis enthält eine **saubere IPv4-Testumgebung**, ohne die bestehenden Dual-Stack-Dateien im Repo anzufassen.

## Zweck

- **jetzt**: Testsystem nur mit IPv4 aufbauen
- **später**: auf IPv6 / Dual-Stack erweitern
- bestehende Dateien im Repo bleiben als spätere Zielarchitektur erhalten

## Enthaltene Dateien

- `compose/node-a.yml` – Docker Compose für **PC 1 / Node A**
- `compose/node-b.yml` – Docker Compose für **PC 2 / Node B**
- `keepalived/node-a.conf` – Keepalived **IPv4-only** für Node A
- `keepalived/node-b.conf` – Keepalived **IPv4-only** für Node B
- `velocity/velocity-node-a.toml` – Velocity **IPv4-only** für Node A
- `velocity/velocity-node-b.toml` – Velocity **IPv4-only** für Node B
- `velocity/Dockerfile` – eigenständiger Test-Build für Velocity
- `.env.example` – gemeinsame Lab-Variablen
- `PC1-node-a.md` – Anleitung für **PC 1**
- `PC2-node-b.md` – Anleitung für **PC 2**
- `PC3-nfs.md` – Anleitung für **PC 3**
- `SPAETER-ipv6.md` – Migrationsplan für späteres Dual-Stack

## Empfohlene Reihenfolge

1. `PC3-nfs.md` abarbeiten
2. `PC1-node-a.md` abarbeiten
3. `PC2-node-b.md` abarbeiten
4. Failover testen
5. später `SPAETER-ipv6.md` nutzen

## Wichtige Abgrenzung

Für dieses Testlab verwendest du **nicht**:

- `docker-compose-node-a.yml`
- `docker-compose-node-b.yml`
- `scripts/setup-docker-ipv6.sh`
- die IPv6-Blöcke in den produktiven `keepalived`- und `velocity`-Dateien

Stattdessen verwendest du nur die Dateien in diesem Ordner.

## Schneller Start

Auf **allen Linux-Knoten** das Repo z. B. nach `/opt/gameserver` legen. Danach pro Node:

```bash
cd /opt/gameserver
cp test/ipv4-lab/.env.example test/ipv4-lab/.env
```

Dann die jeweilige PC-Anleitung öffnen:

- **PC 1:** `test/ipv4-lab/PC1-node-a.md`
- **PC 2:** `test/ipv4-lab/PC2-node-b.md`
- **PC 3:** `test/ipv4-lab/PC3-nfs.md`

## Testziel

Am Ende des IPv4-Labs solltest du Folgendes haben:

- Spieler joinen über die **IPv4-VIP**
- Node A hält die VIP im Normalbetrieb
- Node B übernimmt nach Ausfall von Node A
- NFS liefert die gemeinsam genutzten Weltdaten
- die produktiven Dual-Stack-Dateien bleiben unberührt für die spätere IPv6-Phase

