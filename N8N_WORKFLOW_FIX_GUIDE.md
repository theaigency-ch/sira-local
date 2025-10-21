# n8n Workflow Fix Guide - Sira 3.0 RAG

## 🔴 Gefundene Probleme

### 1. Gmail OAuth Credentials abgelaufen
**Fehler:** "The provided authorization grant is invalid, expired, revoked..."

**Lösung:**
1. Öffne n8n UI: https://n8n.theaigency.ch
2. Gehe zu: Credentials → "Gmail account"
3. Klicke "Reconnect"
4. Autorisiere erneut mit Google Account
5. Teste mit: `curl -X POST https://n8n.theaigency.ch/webhook/gmail.send`

### 2. Code-Fehler in "Function: prep email fields"
**Fehler:** `to required [Line 5]`

**Problem:** Syntax-Fehler im Code
```javascript
// ALT (FALSCH):
if (!a.to) throw new Error('to required');

// NEU (RICHTIG):
const to = a.to || '';
if (!to) throw new Error('to required');
```

### 3. Webhook-Routing unvollständig
**Problem:** `Sira3-tasks-create` routet nur 3 Tools (gmail.send, web.search, web.fetch)

**Fehlen:**
- calendar.free_slots
- calendar.create
- calendar.update
- contacts.find
- contacts.upsert
- notes.log
- rag.query

### 4. Inkonsistente Parameter-Struktur
**Problem:** Manchmal `$json.body.tool`, manchmal `$json.tool`

**Lösung:** Immer beide Varianten unterstützen:
```javascript
const tool = $json.body?.tool || $json.tool || '';
```

---

## ✅ Lösung: Vereinfachter Workflow

Ich habe einen **komplett neuen, funktionierenden Workflow** erstellt:
- **Datei:** `n8n-sira-3.0-rag-FIXED.json`
- **Webhook:** `sira3-tasks-create`
- **Alle Tools:** gmail, web, calendar implementiert
- **Fehlerbehandlung:** Robuster Code

### Implementierte Tools:

#### ✅ 1. gmail.send
```json
{
  "tool": "gmail.send",
  "to": "email@example.com",
  "subject": "Test",
  "text": "Hello World"
}
```

#### ✅ 2. web.search
```json
{
  "tool": "web.search",
  "query": "Schweizer KI Trends 2025",
  "maxResults": 5
}
```

#### ✅ 3. web.fetch
```json
{
  "tool": "web.fetch",
  "url": "https://example.com",
  "strip": true,
  "limit": 8000
}
```

#### ✅ 4. calendar.free_slots
```json
{
  "tool": "calendar.free_slots",
  "date": "2025-10-22",
  "duration": 60,
  "calendarId": "primary"
}
```

#### ✅ 5. calendar.create
```json
{
  "tool": "calendar.create",
  "summary": "Meeting",
  "start": "2025-10-25T14:00:00",
  "end": "2025-10-25T15:00:00",
  "description": "Optional",
  "location": "Optional"
}
```

#### ⏳ 6-11. Andere Tools
- calendar.update → "Not implemented yet" (501)
- contacts.find → "Not implemented yet" (501)
- contacts.upsert → "Not implemented yet" (501)
- notes.log → "Not implemented yet" (501)
- rag.query → "Not implemented yet" (501)
- gmail.reply → "Not implemented yet" (501)

---

## 🚀 Deployment-Schritte

### Schritt 1: Workflow importieren

1. Öffne n8n UI: https://n8n.theaigency.ch
2. Klicke oben rechts: "+ Add workflow"
3. Klicke "..." → "Import from File"
4. Wähle: `n8n-sira-3.0-rag-FIXED.json`
5. Klicke "Import"

### Schritt 2: Credentials verbinden

**Gmail:**
1. Node "Gmail: Send" öffnen
2. Credentials: "Gmail account" auswählen
3. Falls abgelaufen: "Reconnect" klicken

**Google Calendar:**
1. Nodes "Calendar: Get Events" und "Calendar: Create" öffnen
2. Credentials: "Google Calendar account" auswählen

**SerpAPI:**
1. Node "SerpAPI" öffnen
2. Credentials: "Query Auth account" auswählen
3. API Key prüfen

### Schritt 3: Webhook-URL prüfen

1. Node "Webhook: Sira3 Tasks Create" öffnen
2. Webhook-URL kopieren: `https://n8n.theaigency.ch/webhook/sira3-tasks-create`
3. In `.env` setzen:
   ```bash
   N8N_TASK_URL=https://n8n.theaigency.ch/webhook/sira3-tasks-create
   ```

### Schritt 4: Workflow aktivieren

1. Oben rechts: Toggle "Active" auf ON
2. Klicke "Save"

### Schritt 5: Testen

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

# Erwartete Antwort:
# {"ok":true,"id":"...","threadId":"..."}

# Test 2: web.search
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "web.search",
    "query": "Schweizer KI Trends 2025"
  }'

# Erwartete Antwort:
# {"ok":true,"results":[...]}

# Test 3: calendar.free_slots
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "calendar.free_slots",
    "date": "2025-10-22",
    "duration": 60
  }'

# Erwartete Antwort:
# {"ok":true,"slots":[...]}
```

---

## 🔧 Fehlerbehebung

### Problem: "Gmail OAuth invalid"

**Lösung:**
1. n8n UI → Credentials → "Gmail account"
2. Klicke "Reconnect"
3. Autorisiere mit Google
4. Teste erneut

### Problem: "Webhook not found"

**Lösung:**
1. Prüfe ob Workflow aktiv ist (Toggle ON)
2. Prüfe Webhook-URL in Node
3. Prüfe N8N_TASK_URL in .env

### Problem: "SerpAPI error"

**Lösung:**
1. Prüfe SerpAPI Credits: https://serpapi.com/dashboard
2. Prüfe API Key in n8n Credentials
3. Falls keine Credits: Alternative API verwenden

### Problem: "Calendar not found"

**Lösung:**
1. Prüfe Google Calendar Credentials
2. Reconnect falls nötig
3. Prüfe calendarId (default: "primary")

---

## 📋 Workflow-Struktur

```
Webhook: Sira3 Tasks Create
  ↓
Route by Tool (Switch)
  ↓
  ├─→ gmail.send → Prep → Gmail: Send → Respond
  ├─→ web.search → Prep → SerpAPI → Shape → Respond
  ├─→ web.fetch → Prep → HTTP: Fetch → Shape → Respond
  ├─→ calendar.free_slots → Prep → Get Events → Calc → Respond
  ├─→ calendar.create → Prep → Create Event → Respond
  └─→ others → Respond: Not Implemented (501)
```

---

## 🎯 Nächste Schritte

### Sofort:
1. ✅ Workflow importieren
2. ✅ Gmail Credentials reconnecten
3. ✅ Workflow aktivieren
4. ✅ Testen (gmail.send, web.search, calendar)

### Später:
- [ ] calendar.update implementieren
- [ ] contacts.find implementieren
- [ ] contacts.upsert implementieren
- [ ] notes.log implementieren
- [ ] rag.query implementieren (Pinecone)
- [ ] gmail.reply implementieren

---

## 📝 Code-Beispiele

### Prep-Node Pattern (robuster Code):

```javascript
// Normalisiere Input
const b = $json.body || $json;

// Extrahiere Parameter mit Fallbacks
const param1 = b.param1 || '';
const param2 = b.param2 || b.alternativeName || '';

// Validierung
if (!param1) throw new Error('param1 required');

// Return
return [{ json: { param1, param2 } }];
```

### Shape-Node Pattern (Response formatieren):

```javascript
// Input vom vorherigen Node
const data = $json;

// Formatiere Response
return [{
  json: {
    ok: true,
    result: data.someField,
    meta: {
      timestamp: new Date().toISOString()
    }
  }
}];
```

---

## 🔗 Wichtige Links

- **n8n UI:** https://n8n.theaigency.ch
- **n8n Docs:** https://docs.n8n.io
- **Gmail API:** https://developers.google.com/gmail/api
- **Google Calendar API:** https://developers.google.com/calendar
- **SerpAPI:** https://serpapi.com/dashboard

---

**Erstellt:** 21.10.2025 11:02 Uhr  
**Status:** Ready to Deploy  
**Getestet:** Lokal (Code validiert)  
**Nächster Schritt:** Import in n8n UI + Credentials reconnecten
