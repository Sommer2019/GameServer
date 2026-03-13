# PC 2 – Node B (BACKUP) im IPv4-Testlab

Diese Anleitung startet **Node B** als Hot-Standby mit Velocity Proxy 2.

## Dateien aus diesem Ordner

Du verwendest für PC 2 nur diese Testdateien:

- `test/ipv4-lab/.env.example`
- `test/ipv4-lab/compose/node-b.yml`
- `test/ipv4-lab/keepalived/node-b.conf`
- `test/ipv4-lab/velocity/velocity-node-b.toml`

## 1. Repo vorbereiten

```bash
cd /opt/gameserver
cp test/ipv4-lab/.env.example test/ipv4-lab/.env
```

## 2. `.env` anpassen

Öffne `test/ipv4-lab/.env` und prüfe mindestens:

- `VELOCITY_SECRET`
- `PROXY_VIP`
- `NODE_A_IP`
- `NODE_B_IP`
- `NFS_SERVER_IP`
- `MC_VERSION`
- `MC_MEMORY`

Die Werte müssen zu PC 1 passen.

## 3. Velocity-Konfiguration anpassen

Öffne `test/ipv4-lab/velocity/velocity-node-b.toml` und setze:

- `forwarding_secret` = gleicher Wert wie `VELOCITY_SECRET` aus `.env`
- `backup` = IPv4 von Node A
- `play.test.local` = gleiche Domain wie auf Node A

## 4. Keepalived-Konfiguration anpassen

Öffne `test/ipv4-lab/keepalived/node-b.conf` und prüfe:

- `interface eth0` → auf dein echtes Interface ändern
- `auth_pass labpass1` → gleicher Wert wie auf Node A
- `192.168.1.200/24` → gleiche VIP wie auf Node A

## 5. NFS-Client mounten

```bash
chmod +x nfs/setup-nfs-client.sh
sudo NFS_SERVER_IP=192.168.1.5 bash nfs/setup-nfs-client.sh
mountpoint /mnt/gamedata
```

## 6. Keepalived installieren und Dateien kopieren

```bash
sudo apt-get update
sudo apt-get install -y keepalived netcat-openbsd
sudo cp test/ipv4-lab/keepalived/node-b.conf /etc/keepalived/keepalived.conf
sudo cp keepalived/check_minecraft.sh /etc/keepalived/check_minecraft.sh
sudo cp keepalived/check_velocity.sh /etc/keepalived/check_velocity.sh
sudo cp keepalived/notify.sh /etc/keepalived/notify.sh
sudo chmod +x /etc/keepalived/check_minecraft.sh
sudo chmod +x /etc/keepalived/check_velocity.sh
sudo chmod +x /etc/keepalived/notify.sh
sudo systemctl enable keepalived
sudo systemctl restart keepalived
```

## 7. Docker-Stack starten

```bash
docker compose -f test/ipv4-lab/compose/node-b.yml --env-file test/ipv4-lab/.env up -d
```

## 8. Node B prüfen

```bash
docker compose -f test/ipv4-lab/compose/node-b.yml ps
docker compose -f test/ipv4-lab/compose/node-b.yml logs --tail=100
ip addr show
sudo systemctl status keepalived
```

## 9. Erwartetes Ergebnis

- `velocity-proxy-2` läuft
- `minecraft-lobby` läuft
- `minecraft-backup` wartet im Standby-Modus
- die IPv4-VIP liegt **noch nicht** auf PC 2, solange PC 1 gesund ist

## 10. Failover-Test

Stoppe auf PC 1 testweise Keepalived oder den Docker-Stack. Danach auf PC 2 prüfen:

```bash
ip addr show
docker compose -f test/ipv4-lab/compose/node-b.yml logs --tail=100
```

Dann sollte die IPv4-VIP auf **PC 2** auftauchen und der Backup-Node aktiv werden.

