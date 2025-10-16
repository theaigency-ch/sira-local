#!/bin/bash
# Verifizierungs-Skript für Memory-Loss-Fix

echo "======================================"
echo "Memory Loss Fix - Verifizierung"
echo "======================================"
echo ""

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. Prüfe Container Status
echo -e "${BLUE}1. Container Status${NC}"
echo "-----------------------------------"
SIRANET_STATUS=$(docker ps --filter "name=siranet" --format "{{.Status}}" 2>/dev/null)
QDRANT_STATUS=$(docker ps --filter "name=qdrant" --format "{{.Status}}" 2>/dev/null)
REDIS_STATUS=$(docker ps --filter "name=redis-sira" --format "{{.Status}}" 2>/dev/null)

if [[ -n "$SIRANET_STATUS" ]]; then
    echo -e "${GREEN}✓ SiraNet:${NC} $SIRANET_STATUS"
else
    echo -e "${RED}✗ SiraNet ist nicht gestartet${NC}"
fi

if [[ -n "$QDRANT_STATUS" ]]; then
    echo -e "${GREEN}✓ Qdrant:${NC} $QDRANT_STATUS"
else
    echo -e "${RED}✗ Qdrant ist nicht gestartet${NC}"
fi

if [[ -n "$REDIS_STATUS" ]]; then
    echo -e "${GREEN}✓ Redis:${NC} $REDIS_STATUS"
else
    echo -e "${RED}✗ Redis ist nicht gestartet${NC}"
fi
echo ""

# 2. Prüfe Qdrant Collections
echo -e "${BLUE}2. Qdrant Collections${NC}"
echo "-----------------------------------"
COLLECTIONS=$(curl -s http://localhost:6333/collections 2>/dev/null | jq -r '.result.collections[].name' 2>/dev/null)

if echo "$COLLECTIONS" | grep -q "sira_memory"; then
    echo -e "${GREEN}✓ Collection 'sira_memory' existiert${NC}"
else
    echo -e "${RED}✗ Collection 'sira_memory' fehlt${NC}"
fi

if echo "$COLLECTIONS" | grep -q "sira_facts"; then
    echo -e "${GREEN}✓ Collection 'sira_facts' existiert${NC}"
else
    echo -e "${RED}✗ Collection 'sira_facts' fehlt${NC}"
fi
echo ""

# 3. Prüfe Collection Details
echo -e "${BLUE}3. Collection Details${NC}"
echo "-----------------------------------"
MEMORY_INFO=$(curl -s http://localhost:6333/collections/sira_memory 2>/dev/null)
FACTS_INFO=$(curl -s http://localhost:6333/collections/sira_facts 2>/dev/null)

MEMORY_POINTS=$(echo "$MEMORY_INFO" | jq -r '.result.points_count' 2>/dev/null)
FACTS_POINTS=$(echo "$FACTS_INFO" | jq -r '.result.points_count' 2>/dev/null)

echo "sira_memory: $MEMORY_POINTS Punkte"
echo "sira_facts: $FACTS_POINTS Punkte"
echo ""

# 4. Prüfe Redis Memory
echo -e "${BLUE}4. Redis Memory Status${NC}"
echo "-----------------------------------"
MEMORY_DATA=$(curl -s -H "x-sira-token: not-required-for-rork-ai" http://localhost:8787/sira/memory 2>/dev/null)
MEMORY_LEN=$(echo "$MEMORY_DATA" | jq -r '.len' 2>/dev/null)

if [[ "$MEMORY_LEN" =~ ^[0-9]+$ ]]; then
    echo -e "Memory-Größe: ${GREEN}$MEMORY_LEN Zeichen${NC}"
    
    if [ "$MEMORY_LEN" -gt 50000 ]; then
        echo -e "${YELLOW}⚠ Memory ist sehr groß (>50k) - Archivierung sollte bald erfolgen${NC}"
    elif [ "$MEMORY_LEN" -gt 10000 ]; then
        echo -e "${GREEN}✓ Memory-Größe ist normal${NC}"
    else
        echo -e "${YELLOW}⚠ Memory ist klein - möglicherweise wurden Daten verloren${NC}"
    fi
else
    echo -e "${RED}✗ Konnte Memory-Größe nicht abrufen${NC}"
fi
echo ""

# 5. Prüfe Startup-Logs
echo -e "${BLUE}5. Startup-Logs (Qdrant Initialisierung)${NC}"
echo "-----------------------------------"
docker logs siranet 2>&1 | grep -E "\[Qdrant\].*Collection" | tail -10
echo ""

# 6. Prüfe Memory-Logs
echo -e "${BLUE}6. Memory-Logs (letzte 10)${NC}"
echo "-----------------------------------"
docker logs siranet 2>&1 | grep -E "\[Memory\]|\[Redis\]" | tail -10
echo ""

# 7. Test: Neue Daten hinzufügen
echo -e "${BLUE}7. Test: Neue Daten hinzufügen${NC}"
echo "-----------------------------------"
read -p "Möchtest du einen Test-Eintrag hinzufügen? (j/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Jj]$ ]]; then
    TEST_NOTE="Test-Eintrag vom $(date '+%Y-%m-%d %H:%M:%S')"
    RESPONSE=$(curl -s -X POST http://localhost:8787/sira/memory/add \
        -H "Content-Type: application/json" \
        -H "x-sira-token: not-required-for-rork-ai" \
        -d "{\"note\":\"$TEST_NOTE\"}" 2>/dev/null)
    
    if echo "$RESPONSE" | grep -q '"ok":true'; then
        echo -e "${GREEN}✓ Test-Eintrag erfolgreich hinzugefügt${NC}"
        
        # Warte kurz und prüfe neue Größe
        sleep 2
        NEW_MEMORY_DATA=$(curl -s -H "x-sira-token: not-required-for-rork-ai" http://localhost:8787/sira/memory 2>/dev/null)
        NEW_MEMORY_LEN=$(echo "$NEW_MEMORY_DATA" | jq -r '.len' 2>/dev/null)
        echo "Neue Memory-Größe: $NEW_MEMORY_LEN Zeichen (vorher: $MEMORY_LEN)"
    else
        echo -e "${RED}✗ Fehler beim Hinzufügen: $RESPONSE${NC}"
    fi
else
    echo "Test übersprungen"
fi
echo ""

# 8. Zusammenfassung
echo "======================================"
echo -e "${BLUE}Zusammenfassung${NC}"
echo "======================================"

ISSUES=0

# Prüfe kritische Punkte
if [[ -z "$SIRANET_STATUS" ]]; then
    echo -e "${RED}✗ SiraNet läuft nicht${NC}"
    ((ISSUES++))
fi

if ! echo "$COLLECTIONS" | grep -q "sira_memory"; then
    echo -e "${RED}✗ Collection 'sira_memory' fehlt${NC}"
    ((ISSUES++))
fi

if ! echo "$COLLECTIONS" | grep -q "sira_facts"; then
    echo -e "${RED}✗ Collection 'sira_facts' fehlt${NC}"
    ((ISSUES++))
fi

if [[ ! "$MEMORY_LEN" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}✗ Memory nicht erreichbar${NC}"
    ((ISSUES++))
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ Alle Checks bestanden!${NC}"
    echo ""
    echo "Das System ist bereit. Du kannst jetzt:"
    echo "1. Neue Informationen eingeben (z.B. 'Merke dir: Mein Lieblingsessen ist Pizza')"
    echo "2. Mit Sira chatten und sie wird sich an alles erinnern"
    echo "3. Die Logs überwachen: docker logs -f siranet"
else
    echo -e "${RED}✗ $ISSUES Problem(e) gefunden${NC}"
    echo ""
    echo "Nächste Schritte:"
    echo "1. Prüfe ob alle Container laufen: docker-compose ps"
    echo "2. Prüfe Logs: docker logs siranet"
    echo "3. Falls nötig, neu bauen: docker-compose build --no-cache siranet"
    echo "4. Neu starten: docker-compose up -d"
fi

echo ""
echo "Weitere Befehle:"
echo "- Logs live: docker logs -f siranet"
echo "- Collections: curl http://localhost:6333/collections | jq"
echo "- Memory: curl -H 'x-sira-token: not-required-for-rork-ai' http://localhost:8787/sira/memory | jq"
echo ""
