#!/bin/bash

# Sira Facts Import Script
# Lädt alle Fakten aus sira-facts.md in Qdrant

TOKEN="${SIRA_TOKEN:-IHR_TOKEN_HIER}"
URL="https://sira.theaigency.ch/sira/facts/import"

echo "📤 Importiere Fakten nach Qdrant..."

# Lese Datei und escape für JSON
FACTS=$(cat sira-facts.md | jq -Rs .)

# Sende Request
RESPONSE=$(curl -s -X POST "$URL" \
  -H "x-sira-token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"text\": $FACTS}")

echo "$RESPONSE" | jq .

# Prüfe Erfolg
SUCCESS=$(echo "$RESPONSE" | jq -r '.ok')
if [ "$SUCCESS" = "true" ]; then
  IMPORTED=$(echo "$RESPONSE" | jq -r '.imported')
  FAILED=$(echo "$RESPONSE" | jq -r '.failed')
  echo "✅ Import erfolgreich: $IMPORTED Fakten importiert, $FAILED fehlgeschlagen"
else
  echo "❌ Import fehlgeschlagen"
  exit 1
fi
