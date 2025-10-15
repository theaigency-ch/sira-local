# Änderungen für VPS-Deployment

## Zusammenfassung
Nur **eine Datei** wurde geändert: `Dockerfile`

## Deployment-Schritte

### 1. Dockerfile auf VPS kopieren
```bash
# Von deinem Mac aus:
scp Dockerfile root@DEIN_VPS_IP:/root/siranet/Dockerfile

# Oder mit deinem spezifischen Pfad:
scp Dockerfile root@DEIN_VPS_IP:/opt/siranet/Dockerfile
```

### 2. Auf VPS einloggen und neu bauen
```bash
ssh root@DEIN_VPS_IP
cd /root/siranet  # oder dein Projekt-Pfad

# Container stoppen
docker-compose down

# Neu bauen (ohne Cache, um sicher zu gehen)
docker-compose build --no-cache siranet

# Starten
docker-compose up -d

# Logs prüfen
docker logs -f siranet | grep -E "(Redis|Memory)"
```

### 3. Testen
```bash
# Redis-Verbindung testen
curl -H "x-sira-token: not-required-for-rork-ai" \
  http://localhost:8787/sira/diag/data | jq

# Memory-Endpoint testen
curl -X POST -H "Content-Type: application/json" \
  -H "x-sira-token: not-required-for-rork-ai" \
  -d '{"user":"Test","assistant":"Response"}' \
  http://localhost:8787/sira/rt/memory/save

# Memory abrufen
curl -H "x-sira-token: not-required-for-rork-ai" \
  http://localhost:8787/sira/memory | jq
```

## Was wurde geändert?

### Änderung 1: Verbesserte Redis-Funktionen (Zeilen 96-158)
- Timeout erhöht: 5s → 8s
- Besseres Error-Logging
- Retry-Logik mit 3 Versuchen

### Änderung 2: Neuer Server-Endpoint (Zeilen 572-579)
- `/sira/rt/memory/save` - Speichert Realtime-Transkripte

### Änderung 3: Client-seitige Memory-Erfassung (Zeilen 410-509)
- Erfasst User- und Assistant-Transkripte
- Automatische Speicherung nach Gespräch
- Fallback beim Schließen der Seite

## Wichtig für VPS

### Firewall-Regeln
Falls nicht schon offen:
```bash
ufw allow 8787/tcp
```

### SSL/HTTPS
Wenn du HTTPS verwendest, stelle sicher dass:
- Nginx/Caddy als Reverse Proxy läuft
- WebSocket-Verbindungen erlaubt sind

### Monitoring
```bash
# Live-Logs
docker logs -f siranet

# Nur Redis/Memory
docker logs -f siranet | grep -E "(Redis|Memory)"

# Container-Status
docker ps
```

## Rollback (falls nötig)

Falls etwas schiefgeht:
```bash
# Altes Image wiederherstellen
docker-compose down
docker-compose up -d

# Oder spezifisches Image-Tag verwenden
docker tag windsurf-project-siranet:latest windsurf-project-siranet:backup
```

## Unterschiede Mac vs VPS

### Mac (Docker Desktop):
- Host: `localhost:8787`
- Redis: `redis-sira` (Docker-Netzwerk)

### VPS:
- Host: `https://sira.theaigency.ch` (oder deine Domain)
- Redis: `redis-sira` (gleich)
- Möglicherweise hinter Reverse Proxy (Nginx/Caddy)

## Erwartete Logs auf VPS

Nach dem Start solltest du sehen:
```
[Redis] Konfiguration geladen: { host: 'redis-sira', port: 6379, hasPassword: true }
[Redis] Lade Memory beim Start...
[Redis] Verbindung hergestellt zu redis-sira:6379
SiraNet ready on 8787
```

Bei Realtime-Nutzung:
```
[Memory] Realtime-Gespräch gespeichert
[Redis] Memory gespeichert (XXX Zeichen)
```
