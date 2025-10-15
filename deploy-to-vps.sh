#!/bin/bash
# Deployment-Skript für VPS

# KONFIGURATION - ANPASSEN!
VPS_HOST="root@DEIN_VPS_IP"  # z.B. root@123.45.67.89
VPS_PATH="/root/siranet"      # Pfad auf dem VPS

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Deployment zu VPS ==="
echo ""

# Prüfen ob Konfiguration gesetzt ist
if [[ "$VPS_HOST" == "root@DEIN_VPS_IP" ]]; then
    echo -e "${RED}FEHLER: Bitte VPS_HOST in diesem Skript anpassen!${NC}"
    echo "Öffne deploy-to-vps.sh und setze:"
    echo "  VPS_HOST=\"root@deine-ip\""
    echo "  VPS_PATH=\"/pfad/zum/projekt\""
    exit 1
fi

echo -e "${YELLOW}1. Backup des alten Dockerfile auf VPS erstellen...${NC}"
ssh $VPS_HOST "cd $VPS_PATH && cp Dockerfile Dockerfile.backup.\$(date +%Y%m%d_%H%M%S)"
echo ""

echo -e "${YELLOW}2. Dockerfile zum VPS kopieren...${NC}"
scp Dockerfile $VPS_HOST:$VPS_PATH/Dockerfile
if [ $? -ne 0 ]; then
    echo -e "${RED}Fehler beim Kopieren!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Dockerfile kopiert${NC}"
echo ""

echo -e "${YELLOW}3. Container auf VPS neu bauen und starten...${NC}"
ssh $VPS_HOST << 'ENDSSH'
cd /root/siranet  # oder dein VPS_PATH

echo "Container stoppen..."
docker-compose down

echo "Neues Image bauen..."
docker-compose build --no-cache siranet

echo "Container starten..."
docker-compose up -d

echo "Warte 5 Sekunden..."
sleep 5

echo ""
echo "=== Container-Status ==="
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "=== Letzte Logs ==="
docker logs --tail 15 siranet

echo ""
echo "=== Redis-Test ==="
REDIS_TEST=$(docker exec redis-sira redis-cli -a DohajERz0wlqQiIqzrMuJtVlKxxlSQA71aYYHeU1t2w PING 2>&1)
if [[ "$REDIS_TEST" == *"PONG"* ]]; then
    echo "✓ Redis funktioniert"
else
    echo "✗ Redis Fehler: $REDIS_TEST"
fi
ENDSSH

echo ""
echo -e "${GREEN}=== Deployment abgeschlossen ===${NC}"
echo ""
echo "Nächste Schritte:"
echo "1. Teste Realtime UI: https://sira.theaigency.ch/sira/rt/v2/ptt"
echo "2. Prüfe Logs: ssh $VPS_HOST 'docker logs -f siranet'"
echo "3. Teste Memory: curl -H 'x-sira-token: not-required-for-rork-ai' https://sira.theaigency.ch/sira/memory"
echo ""
echo "Bei Problemen Rollback:"
echo "ssh $VPS_HOST 'cd $VPS_PATH && docker-compose down && cp Dockerfile.backup.* Dockerfile && docker-compose up -d'"
echo ""
