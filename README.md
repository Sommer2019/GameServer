# GameServer – Hochverfügbares Minecraft-Setup (HA)

Dieses Repository enthält das vollständige Infrastruktur-Setup für einen
hochverfügbaren Minecraft-GameServer mit **Hot-Standby**, **doppeltem Velocity-Proxy**,
**Virtual IP (VIP via Keepalived)** und **dediziertem NFS-Storage** auf drei physischen Rechnern.

---

## Architektur-Übersicht

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│             Proxy VIP: 192.168.1.200 (Keepalived)       │
│  Players connect here – VIP floats between Node A & B   │
└──────────────────┬──────────────────────────────────────┘
                   │  routes to MASTER node
       ┌───────────┴───────────┐
       │                       │
       ▼                       ▼
┌──────────────────┐   ┌──────────────────┐
│  PC 1 – Node A   │   │  PC 2 – Node B   │
│  192.168.1.10    │   │  192.168.1.11    │
│                  │   │                  │
│  velocity-proxy-1│   │  velocity-proxy-2│  ← both always running;
│  (MASTER / activ)│   │  (BACKUP / bereit)   traffic only on VIP-holder
│        │         │   │        │         │
│        ▼         │   │        ▼         │
│  minecraft-      │   │  minecraft-      │
│  primary         │   │  backup          │
│  (läuft)         │   │  (watchdog-      │
│                  │   │   gesteuert)     │
└────────┬─────────┘   └────────┬─────────┘
         │                      │
         └──────────┬───────────┘
                    │  NFS mount (hard,intr) über internes VLAN
                    ▼
          ┌─────────────────┐
          │  PC 3 – NFS     │
          │  192.168.1.5    │
          │  /srv/gamedata  │
          │  (Weltdaten,    │
          │   session.lock) │
          └─────────────────┘
```

| Maschine | Services | Keepalived-Rolle |
|---|---|---|
| **PC 1 – Node A** | `minecraft-primary` + `velocity-proxy-1` | MASTER (priority 110) |
| **PC 2 – Node B** | `minecraft-backup` + `velocity-proxy-2` | BACKUP (priority 100) |
| **PC 3 – NFS**    | NFS-Server (`/srv/gamedata`) | — |

| Komponente | Rolle |
|---|---|
| **Keepalived** | Verwaltet die Proxy-VIP; trackt Velocity- und Minecraft-Health |
| **NFS / Shared Disk** | Hält die Welt-Daten + `session.lock` |
| **minecraft-primary** | Primärer Gameserver – hat aktiven Dateizugriff |
| **minecraft-backup** | Backup – Watchdog wartet auf Lock-Freigabe |
| **velocity-proxy-1** | Velocity auf Node A – aktiv wenn VIP hier liegt |
| **velocity-proxy-2** | Velocity auf Node B – aktiv nach Failover |

---

## Verzeichnisstruktur

```
GameServer/
├── docker-compose-node-a.yml      # Node A: Minecraft Primary + Velocity Proxy 1
├── docker-compose-node-b.yml      # Node B: Minecraft Backup  + Velocity Proxy 2
├── .env.example                   # Vorlage für Umgebungsvariablen
├── .gitignore
│
├── keepalived/
│   ├── node-a/
│   │   └── keepalived.conf        # MASTER – verwaltet Proxy VIP
│   ├── node-b/
│   │   └── keepalived.conf        # BACKUP – übernimmt VIP bei Ausfall
│   ├── check_minecraft.sh         # Health-Check: Minecraft-Container
│   ├── check_velocity.sh          # Health-Check: Velocity-Proxy-Container
│   └── notify.sh                  # State-Change-Benachrichtigung
│
├── nfs/
│   ├── setup-nfs-server.sh        # Auf PC 3 ausführen (NFS-Server einrichten)
│   ├── setup-nfs-client.sh        # Auf Node A & B ausführen (NFS mounten)
│   └── exports                    # /etc/exports Referenz-Vorlage für PC 3
│
├── velocity/
│   ├── velocity.toml              # Shared config für beide Proxy-Instanzen
│   └── Dockerfile                 # Velocity-Container-Build
│
└── scripts/
    ├── watchdog.sh                # Session-Lock-Monitor (läuft in minecraft-backup)
    ├── entrypoint-backup.sh       # Entrypoint für Backup-Container
    └── security-iptables.sh       # Firewall-Härtung (auf beiden Nodes ausführen)
```

---

## Voraussetzungen

- Drei physische Rechner / VMs mit **Linux** (Debian/Ubuntu empfohlen)
- **Docker** und **Docker Compose** auf Node A und Node B
- **Keepalived** auf Node A und Node B
- **nfs-kernel-server** auf PC 3 (NFS-Server)
- Internes Netzwerk (VLAN/Switch) zwischen allen drei Rechnern

---

## Schritt-für-Schritt-Einrichtung

### 1. Umgebungsvariablen konfigurieren

Auf **Node A und Node B** je eine `.env`-Datei anlegen:

```bash
cp .env.example .env
nano .env   # alle IPs und Secrets eintragen
```

> **Wichtig:** Committe niemals die `.env`-Datei in Git!

---

### 2. NFS-Server einrichten (PC 3 – dedizierter Storage-Rechner)

```bash
# Nur auf PC 3 ausführen:
chmod +x nfs/setup-nfs-server.sh
sudo nfs/setup-nfs-server.sh
```

Das Skript installiert `nfs-kernel-server`, erstellt `/srv/gamedata/worlds`,
schreibt `/etc/exports` mit Zugriff exklusiv für Node A und Node B
und startet den NFS-Dienst.

---

### 3. NFS-Client mounten (Node A und Node B)

```bash
# Auf Node A ausführen:
chmod +x nfs/setup-nfs-client.sh
sudo NFS_SERVER_IP=192.168.1.5 nfs/setup-nfs-client.sh

# Auf Node B dasselbe:
sudo NFS_SERVER_IP=192.168.1.5 nfs/setup-nfs-client.sh
```

Die Mount-Option `hard,intr` stellt sicher, dass der Prozess **wartet** statt
mit einem IO-Fehler abzustürzen, wenn das Netzwerk kurz weg ist.

```bash
# Verify:
mountpoint /mnt/gamedata && df -h /mnt/gamedata
```

---

### 4. Keepalived einrichten (Node A und Node B)

```bash
sudo apt-get install -y keepalived netcat-openbsd
```

**Auf Node A:**
```bash
sudo cp keepalived/node-a/keepalived.conf /etc/keepalived/keepalived.conf
sudo cp keepalived/check_minecraft.sh     /etc/keepalived/check_minecraft.sh
sudo cp keepalived/check_velocity.sh      /etc/keepalived/check_velocity.sh
sudo cp keepalived/notify.sh              /etc/keepalived/notify.sh
sudo chmod +x /etc/keepalived/check_minecraft.sh \
              /etc/keepalived/check_velocity.sh \
              /etc/keepalived/notify.sh
```

**Auf Node B** (analog mit node-b/keepalived.conf):
```bash
sudo cp keepalived/node-b/keepalived.conf /etc/keepalived/keepalived.conf
sudo cp keepalived/check_minecraft.sh     /etc/keepalived/check_minecraft.sh
sudo cp keepalived/check_velocity.sh      /etc/keepalived/check_velocity.sh
sudo cp keepalived/notify.sh              /etc/keepalived/notify.sh
sudo chmod +x /etc/keepalived/check_minecraft.sh \
              /etc/keepalived/check_velocity.sh \
              /etc/keepalived/notify.sh
```

In **beiden** `keepalived.conf`-Dateien anpassen:
- `interface` → Netzwerk-Interface (z.B. `eth0`, `ens3`)
- `192.168.1.200/24` → Proxy VIP (öffentliche IP, auf die DNS zeigt)
- `CHANGE_ME_SECRET` → starkes, gemeinsames Passwort

```bash
sudo systemctl enable keepalived
sudo systemctl start keepalived
ip addr show   # VIP sollte auf Node A sichtbar sein
```

---

### 5. Node A starten (Minecraft Primary + Velocity Proxy 1)

```bash
# Velocity-Image bauen und alle Services starten:
docker compose -f docker-compose-node-a.yml --env-file .env up -d

# Logs beobachten:
docker compose -f docker-compose-node-a.yml logs -f
```

---

### 6. Node B starten (Minecraft Backup + Velocity Proxy 2)

```bash
docker compose -f docker-compose-node-b.yml --env-file .env up -d
docker compose -f docker-compose-node-b.yml logs -f
```

Velocity Proxy 2 startet sofort und ist bereit. Minecraft Backup bleibt im
Watchdog-Wartemodus:

```
[watchdog] Watchdog started on backup node.
[watchdog] Waiting for primary lock to disappear at: /data/worlds/world/session.lock
```

---

### 7. velocity.toml anpassen

In `velocity/velocity.toml` die Werte eintragen:
- `backup = "192.168.1.11:25565"` → reale IP von Node B
  *(auf Node B: `backup = "192.168.1.10:25565"` für Node A)*
- `"play.yourdomain.de"` → Spieler-Domain
- `forwarding_secret` → gleicher Wert wie `VELOCITY_SECRET` in `.env`
- DNS / Port-Forwarding: Domain/öffentliche IP → **Proxy VIP (192.168.1.200):25565**

---

### 8. Firewall härten (Node A und Node B)

```bash
chmod +x scripts/security-iptables.sh
sudo scripts/security-iptables.sh
```

---

## Failover-Ablauf

```
1. Node A (Primary) fällt aus
        │
        ▼
2. Keepalived-Health-Checks schlagen fehl (check_velocity.sh / check_minecraft.sh)
   Priorität auf Node A sinkt unter 100 → Node B gewinnt das VRRP
   → Proxy VIP springt von Node A auf Node B (~1–2 Sekunden)
        │
        ▼
3. Velocity Proxy 2 (Node B) empfängt jetzt Spieler-Traffic
   Velocity versucht zuerst localhost:25565 (minecraft-backup)
   → noch nicht aktiv, Fallback auf 192.168.1.10:25565 (Node A)
   → Node A ist tot, Timeout → Fehler / Spieler warten kurz
        │
        ▼
4. watchdog.sh erkennt, dass session.lock auf NFS verschwunden ist
   (nach LOCK_TIMEOUT Sekunden, Standard: 10 s)
   → startet Minecraft-Prozess auf Node B
        │
        ▼
5. Velocity Proxy 2 verbindet Spieler erfolgreich mit localhost:25565 (Node B)
        │
        ▼
6. Spieler sind wieder online auf Node B
```

**Gesamte Downtime:** ~10–30 Sekunden (konfigurierbar über `LOCK_TIMEOUT`)

---

## Sicherheit

- **Velocity-Port (25565):** Öffentlich zugänglich – Velocity übernimmt Authentifizierung.
- **Minecraft-Backend-Port:** Per Docker auf `127.0.0.1` gebunden → nur lokaler Proxy-Zugriff.
- **NFS:** Läuft über ein separates internes VLAN (PC 3 ist nur intern erreichbar).
- **Velocity Modern Forwarding:** Spieler-IPs werden sicher von Velocity an die Backends weitergegeben.
- **Secrets:** `VELOCITY_SECRET` und `KEEPALIVED_AUTH_PASS` niemals in Git commiten.
- **DDoS:** Für DDoS-Schutz Cloudflare Spectrum oder TCP-Shield vor die Proxy-VIP schalten.

---

## Watchdog – Umgebungsvariablen

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
sudo mount -a                     # Manuell alle fstab-Einträge mounten
showmount -e 192.168.1.5          # NFS-Exporte auf PC 3 prüfen
sudo systemctl status nfs-server  # NFS-Dienst auf PC 3 prüfen
```

### VIP springt nicht um
```bash
sudo systemctl status keepalived
sudo journalctl -u keepalived -n 50
sudo /etc/keepalived/check_velocity.sh   # Skripte manuell testen
sudo /etc/keepalived/check_minecraft.sh
```

### Watchdog promotet nicht
```bash
docker logs minecraft-backup
ls -la /mnt/gamedata/worlds/world/session.lock
```

### Velocity verbindet nicht mit Backend
```bash
docker logs velocity-proxy-1    # oder velocity-proxy-2
# velocity.toml prüfen: forwarding_secret, Backend-IPs
# Paper-Config prüfen: paper-global.yml → proxies.velocity.secret
```
