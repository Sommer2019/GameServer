# GameServer – Hochverfügbares Minecraft-Setup (HA)

Dieses Repository enthält das vollständige Infrastruktur-Setup für einen
hochverfügbaren Minecraft-GameServer mit **Hot-Standby**, **Virtual IP (VIP)**
und **Velocity-Proxy** auf zwei physischen Nodes.

---

## Architektur-Übersicht

```
Internet
    │
    ▼
┌─────────────────────────────────┐
│         Velocity Proxy          │  ← Port 25565 (öffentlich)
│   (docker-compose-velocity.yml) │
└────────────┬────────────────────┘
             │  Weiterleitung auf aktiven Backend
    ┌────────┴─────────┐
    │                  │
    ▼                  ▼
┌──────────┐      ┌──────────┐
│  Node A  │      │  Node B  │
│ (MASTER) │      │ (BACKUP) │
│ Port 25565│      │ Port 25565│
└────┬─────┘      └────┬─────┘
     │                 │
     └────────┬────────┘
              │ NFS-Mount (hard,intr)
              ▼
    ┌─────────────────┐
    │   NFS-Server    │
    │ /srv/gamedata   │
    │  (Weltdaten)    │
    └─────────────────┘
```

| Komponente | Rolle | Status |
|---|---|---|
| **Keepalived** | Verwaltet die virtuelle IP (VIP) | Aktiv auf beiden Nodes |
| **NFS / Shared Disk** | Hält die Welt-Daten | Permanent gemountet |
| **Docker Container A** | Primärer Gameserver | Läuft & hat Dateizugriff |
| **Docker Container B** | Backup Gameserver | Läuft (Wartemodus/Standby) |
| **Velocity Proxy** | Leitet Spieler um | Aktiv (prüft Erreichbarkeit) |

---

## Verzeichnisstruktur

```
GameServer/
├── docker-compose-node-a.yml      # Primärer Minecraft-Container
├── docker-compose-node-b.yml      # Backup-Container (Hot-Standby)
├── docker-compose-velocity.yml    # Velocity-Proxy
├── .env.example                   # Vorlage für Umgebungsvariablen
├── .gitignore
│
├── keepalived/
│   ├── node-a/
│   │   └── keepalived.conf        # Keepalived-Konfig für Node A (MASTER)
│   ├── node-b/
│   │   └── keepalived.conf        # Keepalived-Konfig für Node B (BACKUP)
│   ├── check_minecraft.sh         # Health-Check-Skript für Keepalived
│   └── notify.sh                  # State-Change-Benachrichtigung
│
├── nfs/
│   ├── setup-nfs-server.sh        # NFS-Server einrichten (einmalig)
│   ├── setup-nfs-client.sh        # NFS-Client mounten (auf beiden Nodes)
│   └── exports                    # /etc/exports-Referenz
│
├── velocity/
│   ├── velocity.toml              # Velocity-Proxy-Konfiguration
│   └── Dockerfile                 # Velocity-Container-Build
│
└── scripts/
    ├── watchdog.sh                # Session-Lock-Monitor (läuft in Container B)
    ├── entrypoint-backup.sh       # Entrypoint für Backup-Container
    └── security-iptables.sh       # Firewall-Härtung (iptables)
```

---

## Voraussetzungen

- Zwei physische Maschinen / VMs mit **Linux** (Debian/Ubuntu empfohlen)
- **Docker** und **Docker Compose** auf beiden Nodes
- **Keepalived** auf beiden Nodes (wird per Skript installiert)
- Ein **NFS-Server** (kann eine dritte Maschine oder Node A selbst sein)
- Netzwerk-Konnektivität zwischen allen Komponenten

---

## Schritt-für-Schritt-Einrichtung

### 1. Umgebungsvariablen konfigurieren

Kopiere `.env.example` nach `.env` und passe alle Werte an:

```bash
cp .env.example .env
# Öffne .env und trage alle IP-Adressen und Secrets ein
nano .env
```

> **Wichtig:** Committe niemals die `.env`-Datei!

---

### 2. NFS-Server einrichten

Führe dieses Skript **einmalig** auf dem NFS-Server-Rechner aus:

```bash
# NFS-Server-IP-Adressen in setup-nfs-server.sh anpassen, dann:
chmod +x nfs/setup-nfs-server.sh
sudo nfs/setup-nfs-server.sh
```

Das Skript:
- Installiert `nfs-kernel-server`
- Erstellt `/srv/gamedata/worlds`
- Schreibt `/etc/exports` mit Zugriff nur für Node A und Node B
- Startet den NFS-Dienst

---

### 3. NFS-Client auf beiden Nodes einrichten

Führe dieses Skript auf **Node A** und **Node B** aus:

```bash
chmod +x nfs/setup-nfs-client.sh
sudo NFS_SERVER_IP=192.168.1.5 nfs/setup-nfs-client.sh
```

Die Mount-Option `hard,intr` stellt sicher, dass der Prozess wartet (anstatt
mit einem IO-Fehler abzustürzen), wenn das Netzwerk kurz nicht erreichbar ist.

Überprüfe den Mount:
```bash
mountpoint /mnt/gamedata
df -h /mnt/gamedata
```

---

### 4. Keepalived einrichten

Installiere Keepalived auf **beiden Nodes**:

```bash
sudo apt-get install -y keepalived
```

Kopiere die Konfigurationsdateien:

```bash
# Auf Node A:
sudo cp keepalived/node-a/keepalived.conf /etc/keepalived/keepalived.conf
sudo cp keepalived/check_minecraft.sh     /etc/keepalived/check_minecraft.sh
sudo cp keepalived/notify.sh              /etc/keepalived/notify.sh
sudo chmod +x /etc/keepalived/check_minecraft.sh /etc/keepalived/notify.sh

# Auf Node B:
sudo cp keepalived/node-b/keepalived.conf /etc/keepalived/keepalived.conf
sudo cp keepalived/check_minecraft.sh     /etc/keepalived/check_minecraft.sh
sudo cp keepalived/notify.sh              /etc/keepalived/notify.sh
sudo chmod +x /etc/keepalived/check_minecraft.sh /etc/keepalived/notify.sh
```

Passe in **beiden** `keepalived.conf`-Dateien an:
- `interface` → dein Netzwerk-Interface (z.B. `eth0`, `ens3`)
- `192.168.1.100/24` → deine gewünschte Virtual IP (VIP)
- `CHANGE_ME_SECRET` → ein starkes, gemeinsames Passwort

Starte Keepalived:

```bash
sudo systemctl enable keepalived
sudo systemctl start keepalived
# Status prüfen:
sudo systemctl status keepalived
ip addr show   # VIP sollte auf Node A sichtbar sein
```

---

### 5. Primären GameServer starten (Node A)

```bash
# In der .env sicherstellen, dass VELOCITY_SECRET gesetzt ist
docker compose -f docker-compose-node-a.yml --env-file .env up -d
docker compose -f docker-compose-node-a.yml logs -f
```

---

### 6. Backup-Container starten (Node B)

```bash
docker compose -f docker-compose-node-b.yml --env-file .env up -d
docker compose -f docker-compose-node-b.yml logs -f
```

Der Container startet, führt aber **keinen** Minecraft-Prozess aus.
Das `watchdog.sh`-Skript überwacht `session.lock` auf dem NFS-Mount.

Watchdog-Log beobachten:
```bash
docker logs -f minecraft-backup
# Erwartete Ausgabe:
# [watchdog] ... Watchdog started on backup node.
# [watchdog] ... Waiting for primary lock to disappear at: /data/worlds/world/session.lock
# [watchdog] ... Lock absent (0/2)...   ← wenn primary aktiv ist, setzt sich der Zähler zurück
```

---

### 7. Velocity Proxy starten

Passe `velocity/velocity.toml` an:
- `main = "192.168.1.10:25565"` → IP von Node A
- `backup = "192.168.1.11:25565"` → IP von Node B
- `"play.yourdomain.de"` → deine Spieler-Domain
- `forwarding_secret` → selber Wert wie `VELOCITY_SECRET` in `.env`

```bash
docker compose -f docker-compose-velocity.yml up -d
docker compose -f docker-compose-velocity.yml logs -f
```

---

### 8. Firewall härten

Führe das iptables-Skript auf **beiden Nodes** aus:

```bash
# IPs in security-iptables.sh anpassen, dann:
chmod +x scripts/security-iptables.sh
sudo scripts/security-iptables.sh
```

Das Skript stellt sicher, dass Port 25565 **ausschließlich** vom Velocity-Proxy
erreichbar ist. NFS-Traffic wird auf das interne Storage-Interface beschränkt.

---

## Failover-Ablauf

```
1. Node A (Primär) fällt aus
        │
        ▼
2. Keepalived erkennt den Ausfall (check_minecraft.sh gibt 1 zurück)
   → VIP springt von Node A auf Node B (~1-2 Sekunden)
        │
        ▼
3. watchdog.sh auf Node B erkennt, dass session.lock verschwunden ist
   (nach LOCK_TIMEOUT Sekunden, Standard: 10s)
        │
        ▼
4. watchdog.sh promoted Node B → startet Minecraft-Prozess
        │
        ▼
5. Velocity-Proxy erkennt, dass 'main' (Node A) nicht antwortet
   → verbindet neue Spieler automatisch mit 'backup' (Node B)
        │
        ▼
6. Spieler können sich neu verbinden und landen auf Node B
```

**Gesamte Downtime:** ca. 10–30 Sekunden (konfigurierbar über `LOCK_TIMEOUT`)

---

## Sicherheit

- **Docker-Ports:** Minecraft-Port 25565 ist über iptables auf die Proxy-IP beschränkt.
- **NFS:** Läuft über ein separates internes VLAN/Interface – kein Weltdaten-Traffic über das öffentliche Netz.
- **Velocity:** Übernimmt die Spieler-Authentifizierung (online_mode=true auf dem Proxy, false auf den Backends).
- **Secrets:** Velocity-Forwarding-Secret und Keepalived-Auth-Passwort nie im Git commiten.
- **DDoS:** Für DDoS-Schutz TCP-Shield oder Cloudflare Spectrum vor Velocity schalten.

---

## Umgebungsvariablen für den Watchdog

| Variable | Standard | Beschreibung |
|---|---|---|
| `SESSION_LOCK_PATH` | `/data/worlds/world/session.lock` | Pfad zur Minecraft-Session-Lock-Datei |
| `CHECK_INTERVAL` | `5` | Prüfintervall in Sekunden |
| `LOCK_TIMEOUT` | `10` | Sekunden ohne Lock, bevor Promotion stattfindet |
| `MINECRAFT_CMD` | `/start` | Start-Befehl des Minecraft-Servers |

---

## Troubleshooting

### NFS-Mount nicht verfügbar
```bash
sudo mount -a           # Manuell alle fstab-Einträge mounten
showmount -e <NFS_IP>   # NFS-Exporte prüfen
```

### VIP springt nicht um
```bash
sudo systemctl status keepalived
sudo journalctl -u keepalived -n 50
/etc/keepalived/check_minecraft.sh   # Skript manuell testen
```

### Watchdog promotet nicht
```bash
docker logs minecraft-backup         # Watchdog-Ausgabe prüfen
ls -la /mnt/gamedata/worlds/world/session.lock   # Lock-Status prüfen
```

### Velocity verbindet nicht
```bash
docker logs velocity-proxy
# In velocity.toml: backend-IPs und forwarding_secret prüfen
# In Paper: paper-global.yml → proxies.velocity.secret muss stimmen
```
