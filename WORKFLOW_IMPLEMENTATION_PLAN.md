# n8n Workflow - Komplette Implementierung

## ✅ Implementierte Tools (11 Total)

### 1. gmail.send ✅
- Email senden
- Parameter: to, subject, text, html, cc, bcc

### 2. gmail.reply ✅
- In Thread antworten
- Parameter: thread_id, text, html

### 3. web.search ✅
- Google-Suche via SerpAPI
- Parameter: query, maxResults

### 4. web.fetch ✅
- Webseite abrufen & parsen
- Parameter: url, strip, limit

### 5. calendar.free_slots ✅
- Freie Zeiten finden
- Parameter: date, duration, calendarId

### 6. calendar.create ✅
- Termin erstellen
- Parameter: summary, start, end, description, location

### 7. calendar.update ✅
- Termin aktualisieren
- Parameter: event_id, summary, start, end, description, location

### 8. contacts.find ✅
- Kontakte suchen
- Parameter: query

### 9. contacts.upsert ✅
- Kontakt erstellen/aktualisieren
- Parameter: name, email, phone

### 10. notes.log ✅
- Notiz in Google Sheet speichern
- Parameter: note, category

### 11. KEIN rag.query/rag.ingest ❌
- Nicht nötig, Sira hat Qdrant
- Nutze stattdessen: /sira/facts/import

## 🗑️ Entfernt (Pinecone-Ballast)

- ❌ rag.query (Pinecone)
- ❌ rag.ingest (Pinecone)
- ❌ HTTP: OpenAI Embeddings (für Pinecone)
- ❌ HTTP: Pinecone Query
- ❌ HTTP: Pinecone Upsert
- ❌ Function: build vector
- ❌ Function: chunk text

**Ersetzt durch:** Sira's eigene `/sira/facts/import` und Qdrant Facts

## 📊 Workflow-Struktur

```
Webhook: sira3-tasks-create
  ↓
Route by Tool (Switch mit 11 Outputs)
  ↓
  ├─→ gmail.send
  ├─→ gmail.reply
  ├─→ web.search
  ├─→ web.fetch
  ├─→ calendar.free_slots
  ├─→ calendar.create
  ├─→ calendar.update
  ├─→ contacts.find
  ├─→ contacts.upsert
  ├─→ notes.log
  └─→ unknown → Error Response
```

## 🔧 Credentials benötigt

1. **Gmail OAuth2** (HhIq3H8VG57NsZOV)
2. **Google Calendar OAuth2** (frnl8B9iRXQE9sT4)
3. **Google Contacts OAuth2** (MRSzUPSzhq5RNdlR)
4. **Google Sheets OAuth2** (5P04PKDMSlk6WLSY)
5. **SerpAPI Query Auth** (sfA06G4FrIXGPzxU)

## 📝 Webhook-URL

```
https://n8n.theaigency.ch/webhook/sira3-tasks-create
```

In Sira `.env`:
```bash
N8N_TASK_URL=https://n8n.theaigency.ch/webhook/sira3-tasks-create
```
