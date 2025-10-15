#!/bin/bash
# Test-Skript für Redis, Qdrant und Email-Versand

echo "=== SiraNet Connection Tests ==="
echo ""

# Farben für Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Test: Container Status
echo "1. Container Status prüfen..."
echo "----------------------------"
docker ps --filter "name=siranet" --filter "name=redis-sira" --filter "name=qdrant" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 2. Test: Redis Verbindung
echo "2. Redis Verbindung testen..."
echo "----------------------------"
REDIS_TEST=$(docker exec redis-sira redis-cli -a DohajERz0wlqQiIqzrMuJtVlKxxlSQA71aYYHeU1t2w PING 2>&1)
if [[ "$REDIS_TEST" == *"PONG"* ]]; then
    echo -e "${GREEN}✓ Redis antwortet: PONG${NC}"
else
    echo -e "${RED}✗ Redis Fehler: $REDIS_TEST${NC}"
fi
echo ""

# 3. Test: Qdrant Verbindung
echo "3. Qdrant Verbindung testen..."
echo "----------------------------"
QDRANT_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:6333/readyz)
if [ "$QDRANT_TEST" = "200" ]; then
    echo -e "${GREEN}✓ Qdrant ist bereit (HTTP $QDRANT_TEST)${NC}"
else
    echo -e "${RED}✗ Qdrant nicht erreichbar (HTTP $QDRANT_TEST)${NC}"
fi
echo ""

# 4. Test: SiraNet Diag Endpoint
echo "4. SiraNet Diagnose-Endpoints testen..."
echo "---------------------------------------"
echo "OpenAI Verbindung:"
curl -s http://localhost:8787/sira/diag | jq '.openai' 2>/dev/null || echo "Fehler beim Abrufen"
echo ""
echo "Redis & Qdrant Status:"
curl -s http://localhost:8787/sira/diag/data | jq '.' 2>/dev/null || echo "Fehler beim Abrufen"
echo ""

# 5. Test: Memory Endpoint
echo "5. Memory Endpoint testen..."
echo "----------------------------"
MEMORY_TEST=$(curl -s -H "x-sira-token: not-required-for-rork-ai" http://localhost:8787/sira/memory)
echo "$MEMORY_TEST" | jq '.' 2>/dev/null || echo "$MEMORY_TEST"
echo ""

# 6. Test: Email-Versand (Textmodus)
echo "6. Email-Versand über /sira/ask testen..."
echo "-----------------------------------------"
echo -e "${YELLOW}Hinweis: Dieser Test sendet eine Test-Email an n8n${NC}"
read -p "Test ausführen? (j/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Jj]$ ]]; then
    EMAIL_TEST=$(curl -s -X POST http://localhost:8787/sira/ask \
        -H "Content-Type: application/json" \
        -H "x-sira-token: not-required-for-rork-ai" \
        -d '{"q":"Sende eine Test-Email an privat mit Betreff Test und Text Dies ist ein Test"}')
    echo "$EMAIL_TEST" | jq '.' 2>/dev/null || echo "$EMAIL_TEST"
else
    echo "Test übersprungen"
fi
echo ""

# 7. Test: Realtime Ephemeral Token
echo "7. Realtime Ephemeral Token testen..."
echo "-------------------------------------"
REALTIME_TEST=$(curl -s -H "x-sira-token: not-required-for-rork-ai" http://localhost:8787/sira/rt/ephemeral)
if [[ "$REALTIME_TEST" == *"client_secret"* ]]; then
    echo -e "${GREEN}✓ Realtime Token erfolgreich erstellt${NC}"
else
    echo -e "${RED}✗ Realtime Token Fehler:${NC}"
    echo "$REALTIME_TEST" | jq '.' 2>/dev/null || echo "$REALTIME_TEST"
fi
echo ""

echo "=== Tests abgeschlossen ==="
echo ""
echo "Weitere manuelle Tests:"
echo "- Öffne http://localhost:8787/sira/rt/v2/ptt im Browser"
echo "- Teste Realtime-Sprachsteuerung"
echo "- Sage: 'Sende eine Email an privat mit Betreff Test und Text Hallo Welt'"
echo ""
