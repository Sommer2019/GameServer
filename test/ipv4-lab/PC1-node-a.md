# PC 1 – Node A (MASTER) im IPv4-Testlab

Diese Anleitung startet **Node A** als primären Minecraft-Node mit Velocity Proxy 1 und IPv4-VIP.

## Dateien aus diesem Ordner

Du verwendest für PC 1 nur diese Testdateien:

- `test/ipv4-lab/.env.example`
- `test/ipv4-lab/compose/node-a.yml`
- `test/ipv4-lab/keepalived/node-a.conf`
- `test/ipv4-lab/velocity/velocity-node-a.toml`

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

Standardwerte für dein Lab:

- `PROXY_VIP=172.29.80.200`
- `NODE_A_IP=172.29.80.10`
- `NODE_B_IP=172.29.80.11`
- `NFS_SERVER_IP=172.29.80.5`

## 3. Velocity-Konfiguration anpassen

Öffne `test/ipv4-lab/velocity/velocity-node-a.toml` und setze:

- `forwarding_secret` = gleicher Wert wie `VELOCITY_SECRET` aus `.env`
- `backup` = IPv4 von Node B
- `play.test.local` = deine echte Test-Domain oder Hostname

## 4. Keepalived-Konfiguration anpassen

Öffne `test/ipv4-lab/keepalived/node-a.conf` und prüfe:

- `interface eth0` → auf dein echtes Interface ändern
- `auth_pass labpass1` → auf deinen Lab-Wert ändern
- `172.29.80.200/24` → auf deine VIP ändern

## 5. NFS-Client mounten

```bash
chmod +x nfs/setup-nfs-client.sh
sudo NFS_SERVER_IP=172.29.80.5 bash nfs/setup-nfs-client.sh
mountpoint /mnt/gamedata
```

## 6. Keepalived installieren und Dateien kopieren

```bash
sudo apt-get update
sudo apt-get install -y keepalived netcat-openbsd
sudo cp test/ipv4-lab/keepalived/node-a.conf /etc/keepalived/keepalived.conf
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
docker compose -f test/ipv4-lab/compose/node-a.yml --env-file test/ipv4-lab/.env up -d
```

## 8. Node A prüfen

```bash
docker compose -f test/ipv4-lab/compose/node-a.yml ps
docker compose -f test/ipv4-lab/compose/node-a.yml logs --tail=100
ip addr show
sudo systemctl status keepalived
```

## 9. Erwartetes Ergebnis

- `minecraft-primary` läuft
- `velocity-proxy-1` läuft
- `minecraft-lobby` läuft
- die IPv4-VIP liegt auf **PC 1**

## 10. Optionaler schneller Netztest

Von einem anderen Rechner im gleichen Netz:

```bash
nc -vz 172.29.80.200 25565
```

