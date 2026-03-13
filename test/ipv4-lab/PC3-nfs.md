# PC 3 – NFS-Server (IPv4-Testlab)

Diese Anleitung richtet den **dedizierten NFS-Server** für das IPv4-Testlab ein.

## Ziel

- `/srv/gamedata` auf PC 3 bereitstellen
- Node A und Node B dürfen per IPv4 darauf zugreifen
- noch **kein IPv6** nötig

Für dein Lab gilt dabei standardmäßig:

- **PC 1 / Node A:** `172.29.80.10`
- **PC 2 / Node B:** `172.29.80.11`
- **PC 3 / NFS:** `172.29.80.5`

## 1. Repo bereitstellen

```bash
cd /opt/gameserver
```

## 2. NFS-Server-Skript ausführbar machen

```bash
chmod +x nfs/setup-nfs-server.sh
```

## 3. Vor dem Start die IPs im Skript prüfen

Öffne `nfs/setup-nfs-server.sh` und prüfe diese Werte:

- `NODE_A_IP`
- `NODE_B_IP`
- optional die IPv6-Werte ignorieren, wenn du jetzt nur IPv4 testest

Wenn deine Test-IP-Adressen den Defaults entsprechen (`172.29.80.10`, `172.29.80.11`), musst du nichts ändern.

## 4. NFS-Server einrichten

```bash
sudo bash nfs/setup-nfs-server.sh
```

## 5. Prüfen

```bash
sudo exportfs -v
sudo systemctl status nfs-kernel-server
showmount -e 127.0.0.1
```

## 6. Firewall-Hinweis

Für das Lab reicht es, wenn PC 1 und PC 2 PC 3 auf NFS erreichen können.
Benötigt werden intern insbesondere:

- TCP/UDP 2049
- TCP/UDP 111

Diese Ports **nicht** nach außen freigeben.

## 7. Erfolgskriterium

Wenn alles passt, können PC 1 und PC 2 später Folgendes erfolgreich ausführen:

```bash
sudo NFS_SERVER_IP=172.29.80.5 bash nfs/setup-nfs-client.sh
```

