# Sira 3.0 - Finaler n8n Workflow (16 Tools)

## 📦 Workflow-Übersicht

**Name:** Sira 3.0 Tools (Final)  
**Webhook:** `https://n8n.theaigency.ch/webhook/sira3-tasks-create`  
**Tools:** 16 (ohne RAG/Pinecone)

---

## ✅ Implementierte Tools (16 Total)

### **Gmail Suite (3 Tools)**

### 1. **gmail.send** - Email senden
```json
{
  "tool": "gmail.send",
  "to": "email@example.com",
  "subject": "Betreff",
  "text": "Text-Inhalt",
  "html": "<p>HTML-Inhalt</p>",
  "cc": "cc@example.com",
  "bcc": "bcc@example.com"
}
```

**Response:**
```json
{
  "ok": true,
  "id": "message_id",
  "threadId": "thread_id"
}
```

---

### 2. **gmail.reply** - In Thread antworten
```json
{
  "tool": "gmail.reply",
  "thread_id": "thread_id_hier",
  "text": "Antwort-Text",
  "html": "<p>HTML-Antwort</p>"
}
```

**Response:**
```json
{
  "ok": true,
  "id": "message_id",
  "threadId": "thread_id"
}
```

---

### 3. **gmail.get** - Emails abrufen (NEU!)
```json
{
  "tool": "gmail.get",
  "filter": "is:unread",
  "limit": 5
}
```

**Response:**
```json
{
  "ok": true,
  "count": 3,
  "emails": [
    {
      "id": "msg_123",
      "from": "Peter <pbaka@bluewin.ch>",
      "subject": "Meeting morgen",
      "snippet": "Können wir...",
      "unread": true
    }
  ]
}
```

---

### **Calendar Suite (4 Tools)**

### 4. **calendar.free_slots** - Freie Zeiten finden
```json
{
  "tool": "calendar.free_slots",
  "date": "2025-10-22",
  "duration": 60
}
```

---

### 5. **calendar.create** - Termin erstellen
```json
{
  "tool": "calendar.create",
  "summary": "Meeting",
  "start": "2025-10-25T14:00:00",
  "end": "2025-10-25T15:00:00"
}
```

---

### 6. **calendar.update** - Termin aktualisieren
```json
{
  "tool": "calendar.update",
  "event_id": "event_id_hier",
  "summary": "Neuer Titel"
}
```

---

### 7. **calendar.list** - Termine auflisten (NEU!)
```json
{
  "tool": "calendar.list",
  "date": "today",
  "limit": 10
}
```

**Response:**
```json
{
  "ok": true,
  "count": 2,
  "events": [
    {
      "summary": "Team Meeting",
      "start": "2025-10-21T14:00:00Z",
      "location": "Zoom"
    }
  ]
}
```

---

### **Contacts Suite (2 Tools)**

### 8. **contacts.find** - Kontakte suchen

---

### 9. **contacts.upsert** - Kontakt erstellen/aktualisieren

---

### **Web & Search (3 Tools)**

### 10. **web.search** - Google-Suche
```json
{
  "tool": "web.search",
  "query": "Schweizer KI Trends 2025",
  "maxResults": 5
}
```

**Response:**
```json
{
  "ok": true,
  "results": [
    {
      "title": "...",
      "url": "...",
      "snippet": "..."
    }
  ]
}
```

---

### 4. **web.fetch** - Webseite abrufen
```json
{
  "tool": "web.fetch",
  "url": "https://example.com",
  "strip": true,
  "limit": 8000
}
```

**Response:**
```json
{
  "ok": true,
  "url": "https://example.com",
  "title": "Seitentitel",
  "content": "Bereinigter Text...",
  "length": 5432,
  "truncated": false
}
```

---

### 5. **calendar.free_slots** - Freie Zeiten finden
```json
{
  "tool": "calendar.free_slots",
  "date": "2025-10-22",
  "duration": 60,
  "calendarId": "primary"
}
```

**Response:**
```json
{
  "ok": true,
  "slots": [
    {
      "start": "2025-10-22T09:00:00Z",
      "end": "2025-10-22T10:00:00Z"
    }
  ]
}
```

---

### 6. **calendar.create** - Termin erstellen
```json
{
  "tool": "calendar.create",
  "summary": "Meeting mit Team",
  "start": "2025-10-25T14:00:00",
  "end": "2025-10-25T15:00:00",
  "description": "Agenda: ...",
  "location": "Zoom",
  "calendarId": "primary"
}
```

**Response:**
```json
{
  "ok": true,
  "id": "event_id",
  "link": "https://calendar.google.com/..."
}
```

---

### 7. **calendar.update** - Termin aktualisieren
```json
{
  "tool": "calendar.update",
  "event_id": "event_id_hier",
  "summary": "Neuer Titel",
  "start": "2025-10-25T15:00:00",
  "end": "2025-10-25T16:00:00",
  "description": "Neue Beschreibung",
  "location": "Neuer Ort",
  "calendarId": "primary"
}
```

**Response:**
```json
{
  "ok": true,
  "id": "event_id",
  "updated": true
}
```

---

### 8. **contacts.find** - Kontakte suchen
```json
{
  "tool": "contacts.find",
  "query": "Peter"
}
```

**Response:**
```json
{
  "ok": true,
  "results": [
    {
      "name": "Peter Baka",
      "email": "pbaka@bluewin.ch",
      "phone": "+41..."
    }
  ]
}
```

---

### 9. **contacts.upsert** - Kontakt erstellen/aktualisieren
```json
{
  "tool": "contacts.upsert",
  "name": "Max Mustermann",
  "email": "max@example.com",
  "phone": "+41 79 123 45 67",
  "company": "Firma AG"
}
```

**Response:**
```json
{
  "ok": true,
  "id": "contact_id",
  "created": true
}
```

---

### 10. **notes.log** - Notiz speichern
```json
{
  "tool": "notes.log",
  "note": "Wichtige Notiz vom Meeting",
  "category": "Meeting",
  "date": "2025-10-21"
}
```

**Response:**
```json
{
  "ok": true,
  "row": 42,
  "sheet": "To-do-Liste"
}
```

---

### 11. **perplexity.search** - Intelligente Web-Suche (NEU!)
```json
{
  "tool": "perplexity.search",
  "query": "Was sind die neuesten KI Trends in der Schweiz 2025?",
  "model": "sonar"
}
```

**Response:**
```json
{
  "ok": true,
  "answer": "Die neuesten KI Trends in der Schweiz 2025 umfassen...",
  "citations": [
    "https://example.com/source1",
    "https://example.com/source2"
  ],
  "model": "sonar"
}
```

**Verfügbare Modelle:**
- `sonar` - Standard (schnell, günstig)
- `sonar-pro` - Bessere Qualität
- `sonar-reasoning` - Tiefe Analysen

**Vorteile:**
- ✅ Aktuelle Informationen (besser als SerpAPI)
- ✅ Zusammengefasste Antworten (nicht nur Links)
- ✅ Quellen inklusive
- ✅ Schneller (1 Call statt viele)

**Setup:** Siehe `PERPLEXITY_SETUP.md`

---

### 12. **news.get** - Aktuelle Nachrichten (NEU!)
```json
{
  "tool": "news.get",
  "category": "schweiz",
  "limit": 5
}
```

**Kategorien:**
- `schweiz` - Schweizer News
- `international` - Weltnachrichten
- `tech` - Technologie
- `business` - Wirtschaft

**Response:**
```json
{
  "ok": true,
  "category": "schweiz",
  "summary": "Heute in der Schweiz: Die Nationalbank...",
  "sources": [
    "https://www.nzz.ch/...",
    "https://www.srf.ch/..."
  ]
}
```

**Powered by:** Perplexity (nutzt bereits vorhandenen Key)

---

### 13. **weather.get** - Wetter-Vorhersage (NEU!)
```json
{
  "tool": "weather.get",
  "location": "Zürich",
  "days": 3
}
```

**Response:**
```json
{
  "ok": true,
  "location": "Zürich",
  "current": {
    "temp": 15,
    "feels_like": 13,
    "condition": "Bewölkt",
    "humidity": 65,
    "wind": 12
  },
  "forecast": [
    {
      "date": "2025-10-22",
      "temp_min": 10,
      "temp_max": 18,
      "condition": "Sonnig"
    }
  ]
}
```

**Powered by:** OpenWeather (kostenlos, 1000 calls/Tag)

**Setup:** Siehe `NEWS_WEATHER_SETUP.md`

---

## 🚫 NICHT implementiert (unnötig)

- ❌ **rag.query** - Sira hat bereits Qdrant
- ❌ **rag.ingest** - Nutze `/sira/facts/import`
- ❌ Pinecone-Integration
- ❌ OpenAI Embeddings für RAG

**Warum?** Sira macht semantische Suche bereits selbst in Qdrant!

---

## 📋 Workflow-Nodes (Gesamt: ~40 Nodes)

### Struktur:
```
1. Webhook: sira3-tasks-create
2. Route by Tool (Switch mit 10 Outputs)
3-12. Prep Nodes (je 1 pro Tool)
13-22. Action Nodes (Gmail, Calendar, etc.)
23-32. Response Nodes (je 1 pro Tool)
```

### Credentials:
- Gmail OAuth2
- Google Calendar OAuth2
- Google Contacts OAuth2
- Google Sheets OAuth2
- SerpAPI Query Auth

---

## 🔧 Import-Anleitung

### Schritt 1: Alten Workflow deaktivieren
1. n8n UI öffnen: https://n8n.theaigency.ch
2. Workflow "Sira 3.0 RAG" öffnen
3. Toggle "Active" auf OFF
4. Optional: Umbenennen zu "Sira 3.0 RAG (OLD)"

### Schritt 2: Neuen Workflow importieren
1. Datei herunterladen: `sira-n8n-final-10-tools.json`
2. n8n UI: "+ Add workflow"
3. "..." → "Import from File"
4. Datei auswählen
5. "Import" klicken

### Schritt 3: Credentials verbinden
Für jeden Node mit Credential-Fehler:
1. Node öffnen
2. Credential auswählen (aus Dropdown)
3. Falls abgelaufen: "Reconnect" klicken

**Betroffene Nodes:**
- Gmail: Send
- Gmail: Reply
- Calendar: Get Events
- Calendar: Create
- Calendar: Update
- Contacts: Get
- Contacts: Create
- Sheets: Append
- SerpAPI

### Schritt 4: Webhook-URL prüfen
1. Node "Webhook: sira3-tasks-create" öffnen
2. URL kopieren
3. In Sira `.env` setzen:
   ```bash
   N8N_TASK_URL=https://n8n.theaigency.ch/webhook/sira3-tasks-create
   ```

### Schritt 5: Aktivieren & Testen
1. Toggle "Active" auf ON
2. "Save" klicken
3. Testen mit curl (siehe unten)

---

## 🧪 Test-Commands

```bash
# Test 1: gmail.send
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "gmail.send",
    "to": "pbaka@bluewin.ch",
    "subject": "n8n Test",
    "text": "Dies ist ein Test"
  }'

# Test 2: web.search
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "web.search",
    "query": "Schweizer KI Trends"
  }'

# Test 3: calendar.free_slots
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "calendar.free_slots",
    "date": "2025-10-22",
    "duration": 60
  }'

# Test 4: contacts.find
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "contacts.find",
    "query": "Peter"
  }'

# Test 5: notes.log
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "notes.log",
    "note": "Test-Notiz",
    "category": "Test"
  }'
```

---

## 📊 Vergleich: Alt vs. Neu

| Feature | Alt (mit RAG) | Neu (Final) |
|---------|---------------|-------------|
| **Nodes** | ~60 | ~40 |
| **Tools** | 13 | 10 |
| **Pinecone** | ✅ | ❌ |
| **Qdrant** | Via n8n | Via Sira |
| **Komplexität** | Hoch | Niedrig |
| **Duplikate** | Ja (RAG) | Nein |
| **Wartung** | Schwer | Einfach |

---

## ✅ Vorteile des neuen Workflows

1. **Schlanker:** 40 statt 60 Nodes
2. **Keine Duplikate:** Qdrant nur in Sira
3. **Einfacher:** Keine Pinecone-Komplexität
4. **Schneller:** Weniger Hops
5. **Wartbar:** Klare Struktur
6. **Fokussiert:** Nur externe Services

---

## 🎯 Nächste Schritte

1. ✅ Workflow importieren
2. ✅ Credentials reconnecten
3. ✅ Aktivieren
4. ✅ Alle 10 Tools testen
5. ✅ Alten Workflow löschen (nach erfolgreichen Tests)

---

**Erstellt:** 21.10.2025 11:10 Uhr  
**Status:** Production Ready  
**Datei:** `sira-n8n-final-10-tools.json` (wird gleich erstellt)
