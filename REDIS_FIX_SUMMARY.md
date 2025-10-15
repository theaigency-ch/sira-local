# Redis Memory Fix für Realtime Web UI

## Problem
Wenn die Realtime Web UI verbunden war, funktionierte Redis nicht korrekt und es gab keine Erinnerung an vorherige Gespräche.

## Ursache
Die Realtime-Konversationen liefen direkt zwischen Browser und OpenAI via WebRTC. Der Server-seitige Memory-Mechanismus (`memAppend()`) wurde nie aufgerufen, da die Audio-Konversationen den `/sira/ask` Endpoint umgingen.

## Lösung

### 1. Neuer Server-Endpoint: `/sira/rt/memory/save`
- **Zeilen 572-579 im Dockerfile**
- Empfängt Realtime-Gesprächsdaten (User + Assistant Transkripte)
- Speichert diese in Redis mit dem Präfix `User(Realtime):` und `Sira(Realtime):`

### 2. Client-seitige Transkript-Erfassung
- **Zeilen 410-425 im Dockerfile**
- Neue Variablen: `userTranscript`, `assistantTranscript`
- Neue Funktion: `saveRealtimeMemory()` - sendet Transkripte an Server

### 3. Event-Handler für Memory-Speicherung
- **Zeilen 446-462**: WebSocket-Events werden überwacht
  - `conversation.item.input_audio_transcription.completed` → User-Transkript
  - `response.text.delta` → Assistant-Antwort sammeln
  - `response.text.done` → Gespräch abgeschlossen, Memory speichern

### 4. Zusätzliche Sicherheitsmechanismen
- **Zeilen 494-497**: Timeout nach Sprechen-Ende (3 Sekunden)
- **Zeilen 503-509**: `beforeunload` Event mit `navigator.sendBeacon()` als Fallback

### 5. Verbesserte Redis-Stabilität
- **Zeilen 101-126**: 
  - Timeout erhöht von 5s auf 8s
  - Besseres Error-Logging mit Host/Port-Informationen
  - Detaillierte Fehlerausgaben

### 6. Retry-Logik für Memory-Speicherung
- **Zeilen 138-158**:
  - 3 Versuche mit exponential backoff (1s, 2s)
  - Detailliertes Logging für jeden Versuch
  - Fallback auf In-Memory wenn Redis fehlschlägt

## Testing

### 1. Container neu bauen
```bash
cd /Users/macbookpro/Desktop/CascadeProjects/windsurf-project
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### 2. Logs überwachen
```bash
docker logs -f siranet
```

### 3. Realtime UI testen
1. Öffne: http://localhost:8787/sira/rt/v2/ptt
2. Klicke auf das Mikrofon
3. Sprich eine Frage (z.B. "Wie ist das Wetter heute?")
4. Warte auf Antwort
5. Überprüfe Logs auf `[Memory] Realtime-Gespräch gespeichert`

### 4. Memory überprüfen
```bash
curl -H "x-sira-token: not-required-for-rork-ai" http://localhost:8787/sira/memory | jq
```

### 5. Redis direkt testen
```bash
docker exec redis-sira redis-cli -a DohajERz0wlqQiIqzrMuJtVlKxxlSQA71aYYHeU1t2w GET sira:memory
```

### 6. Vollständiger Test mit Skript
```bash
bash test-connections.sh
```

## Erwartetes Verhalten

### Vorher
- Realtime-Gespräche wurden nicht gespeichert
- Keine Erinnerung an vorherige Audio-Konversationen
- Redis-Verbindungsprobleme bei Realtime-Nutzung

### Nachher
- Realtime-Gespräche werden automatisch in Redis gespeichert
- Transkripte werden mit `User(Realtime):` und `Sira(Realtime):` markiert
- Memory wird beim nächsten Gespräch geladen und verwendet
- Bessere Fehlerbehandlung und Logging
- Retry-Mechanismus verhindert Datenverlust

## Technische Details

### Redis-Verbindung
- Host: `redis-sira` (Docker-Netzwerk)
- Port: `6379`
- Auth: Passwort aus `.env`
- Timeout: 8 Sekunden
- Retry: 3 Versuche mit exponential backoff

### Memory-Format
```
User(Realtime): [Transkript der User-Frage]
Sira(Realtime): [Antwort des Assistenten]
```

### OpenAI Realtime Events
- `conversation.item.input_audio_transcription.completed` - User-Audio wurde transkribiert
- `response.text.delta` - Teil der Assistant-Antwort
- `response.text.done` - Antwort vollständig

## Troubleshooting

### Problem: Memory wird nicht gespeichert
**Lösung**: Überprüfe Docker-Logs auf Redis-Fehler
```bash
docker logs siranet | grep Redis
```

### Problem: Redis Timeout
**Lösung**: Überprüfe Redis-Container
```bash
docker ps | grep redis
docker logs redis-sira
```

### Problem: Keine Transkripte
**Lösung**: Überprüfe Browser-Console
- Öffne DevTools (F12)
- Suche nach `[Memory]` Logs

### Problem: sendBeacon funktioniert nicht
**Lösung**: Das ist normal - sendBeacon ist ein Fallback. Die normale Speicherung erfolgt über `saveRealtimeMemory()`.

## Nächste Schritte

1. **Monitoring**: Überwache die Logs für einige Tage
2. **Optimierung**: Passe Timeout/Retry-Werte bei Bedarf an
3. **Erweiterung**: Füge Memory-Limits pro User hinzu (falls Multi-User)
4. **Backup**: Implementiere regelmäßige Redis-Backups

## Dateien geändert
- `Dockerfile` (Zeilen 96-158, 410-509, 572-579)
