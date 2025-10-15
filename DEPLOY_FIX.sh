#!/bin/bash
# Deployment-Skript für Redis Memory Fix

echo "=== Redis Memory Fix Deployment ==="
echo ""

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Schritt 1: Container stoppen...${NC}"
docker-compose down
echo ""

echo -e "${YELLOW}Schritt 2: Neues Image bauen (ohne Cache)...${NC}"
docker-compose build --no-cache
echo ""

echo -e "${YELLOW}Schritt 3: Container starten...${NC}"
docker-compose up -d
echo ""

echo -e "${YELLOW}Schritt 4: Warte auf Container-Start (10 Sekunden)...${NC}"
sleep 10
echo ""

echo -e "${YELLOW}Schritt 5: Container-Status prüfen...${NC}"
docker ps --filter "name=siranet" --filter "name=redis-sira" --format "table {{.Names}}\t{{.Status}}"
echo ""

echo -e "${YELLOW}Schritt 6: Redis-Verbindung testen...${NC}"
REDIS_TEST=$(docker exec redis-sira redis-cli -a DohajERz0wlqQiIqzrMuJtVlKxxlSQA71aYYHeU1t2w PING 2>&1)
if [[ "$REDIS_TEST" == *"PONG"* ]]; then
    echo -e "${GREEN}✓ Redis funktioniert${NC}"
else
    echo -e "${RED}✗ Redis Fehler: $REDIS_TEST${NC}"
fi
echo ""

echo -e "${YELLOW}Schritt 7: SiraNet Logs (letzte 20 Zeilen)...${NC}"
docker logs --tail 20 siranet
echo ""

echo -e "${GREEN}=== Deployment abgeschlossen ===${NC}"
echo ""
echo "Nächste Schritte:"
echo "1. Öffne http://localhost:8787/sira/rt/v2/ptt"
echo "2. Teste Realtime-Gespräch"
echo "3. Überprüfe Memory: curl -H 'x-sira-token: not-required-for-rork-ai' http://localhost:8787/sira/memory | jq"
echo "4. Live-Logs: docker logs -f siranet"
echo ""
