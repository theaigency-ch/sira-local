#!/bin/bash
# Test-Skript für n8n Tool-Layer auf VPS

VPS_URL="https://sira.theaigency.ch"
TOKEN="not-required-for-rork-ai"

echo "======================================"
echo "n8n Tool-Layer Tests (VPS)"
echo "======================================"
echo ""

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test 1: Email senden (parseMailIntent)
echo -e "${BLUE}Test 1: Email senden (via parseMailIntent)${NC}"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "$VPS_URL/sira/ask" \
  -H "Content-Type: application/json" \
  -H "x-sira-token: $TOKEN" \
  -d '{"q":"Sende eine Email an privat mit Betreff n8n Test und Text Dies ist ein Test"}')

echo "$RESPONSE" | jq '.'
echo ""

# Test 2: Direkter n8n Call - Gmail Send
echo -e "${BLUE}Test 2: Direkter n8n Call - gmail.send${NC}"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "$VPS_URL/sira/input" \
  -H "Content-Type: application/json" \
  -H "x-sira-token: $TOKEN" \
  -d '{
    "tool": "gmail.send",
    "to": "pbaka@bluewin.ch",
    "subject": "Direkter n8n Test",
    "text": "Dies ist ein direkter Test des n8n Webhooks"
  }')

echo "$RESPONSE" | jq '.'
echo ""

# Test 3: Kalender - Freie Slots
echo -e "${BLUE}Test 3: Kalender - Freie Slots${NC}"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "$VPS_URL/sira/input" \
  -H "Content-Type: application/json" \
  -H "x-sira-token: $TOKEN" \
  -d '{
    "tool": "calendar.free_slots",
    "date": "2025-10-22",
    "duration": 60
  }')

echo "$RESPONSE" | jq '.'
echo ""

# Test 4: Kalender - Termin erstellen
echo -e "${BLUE}Test 4: Kalender - Termin erstellen${NC}"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "$VPS_URL/sira/input" \
  -H "Content-Type: application/json" \
  -H "x-sira-token: $TOKEN" \
  -d '{
    "tool": "calendar.create",
    "summary": "n8n Test-Termin",
    "start": "2025-10-25T14:00:00",
    "end": "2025-10-25T15:00:00",
    "description": "Automatisch erstellt via n8n Test"
  }')

echo "$RESPONSE" | jq '.'
echo ""

# Test 5: Kontakte - Suchen
echo -e "${BLUE}Test 5: Kontakte - Suchen${NC}"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "$VPS_URL/sira/input" \
  -H "Content-Type: application/json" \
  -H "x-sira-token: $TOKEN" \
  -d '{
    "tool": "contacts.find",
    "query": "Peter"
  }')

echo "$RESPONSE" | jq '.'
echo ""

# Test 6: Web-Suche
echo -e "${BLUE}Test 6: Web-Suche${NC}"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "$VPS_URL/sira/input" \
  -H "Content-Type: application/json" \
  -H "x-sira-token: $TOKEN" \
  -d '{
    "tool": "web.search",
    "query": "Schweizer KI Trends 2025"
  }')

echo "$RESPONSE" | jq '.'
echo ""

# Test 7: RAG Query
echo -e "${BLUE}Test 7: RAG Query (Wissensbasis)${NC}"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "$VPS_URL/sira/input" \
  -H "Content-Type: application/json" \
  -H "x-sira-token: $TOKEN" \
  -d '{
    "tool": "rag.query",
    "query": "Was ist unser USP?"
  }')

echo "$RESPONSE" | jq '.'
echo ""

echo "======================================"
echo -e "${GREEN}Tests abgeschlossen${NC}"
echo "======================================"
echo ""
echo "Hinweis: Wenn ein Test fehlschlägt, prüfe:"
echo "1. n8n Workflow 'Sira 3.0 RAG' ist aktiv"
echo "2. Webhook-URL ist korrekt konfiguriert"
echo "3. Credentials sind verbunden (Gmail, Calendar, etc.)"
echo "4. N8N_TASK_URL in .env ist gesetzt"
echo ""
