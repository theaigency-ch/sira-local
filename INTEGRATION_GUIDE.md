# SiraNet + FastAPI Integration Guide

## ✅ Integration abgeschlossen!

**Datum**: 24. Oktober 2025  
**Status**: Production Ready

---

## Architektur

```
SiraNet (Port 8787)
  ├─→ OpenAI Realtime API
  ├─→ Redis (Memory)
  ├─→ Qdrant (Facts)
  └─→ FastAPI (sira_api_v3) ← ERSETZT n8n
       └─→ Port 8791
           └─→ /webhook/sira3-tasks-create
               ├─→ Gmail API (direkt)
               ├─→ Calendar API (direkt)
               ├─→ Contacts API (direkt)
               ├─→ Tasks API (direkt)
               ├─→ Sheets API (direkt)
               ├─→ SerpAPI (direkt)
               ├─→ Twilio API (direkt)
               └─→ Web Fetch (direkt)
```

---

## Änderungen

### 1. **docker-compose.yml**
- ✅ `sira_api_v3` Service hinzugefügt
- ✅ Im gleichen Netzwerk (`sira_net`)
- ✅ Depends on: `redis-sira`, `qdrant`
- ✅ Healthcheck konfiguriert

### 2. **.env**
```bash
# ALT (n8n):
N8N_TASK_URL=https://n8n.theaigency.ch/webhook/sira3-tasks-create

# NEU (FastAPI):
N8N_TASK_URL=http://sira_api_v3:8791/webhook/sira3-tasks-create
```

### 3. **Keine Code-Änderungen in SiraNet!**
- ✅ `forwardToN8N()` bleibt unverändert
- ✅ Realtime Voice Flow bleibt unverändert
- ✅ `/sira/input` Endpoint bleibt unverändert

---

## Deployment

### Lokal testen:
```bash
cd ~/Desktop/CascadeProjects/windsurf-project
docker-compose down
docker-compose up --build -d
```

### Logs prüfen:
```bash
docker logs siranet
docker logs sira_api_v3
```

### Testen:
1. **Text Chat**: `http://localhost:8787/sira/ask`
2. **Realtime Voice**: `http://localhost:8787/sira/rt/v2/ptt`
3. **FastAPI Docs**: `http://localhost:8791/docs`

---

## Realtime Voice Flow

```
1. User spricht → OpenAI Realtime API
2. OpenAI erkennt Function Call → response.function_call_arguments.done
3. Frontend: fetch('/sira/input', {tool: "gmail.send", ...})
4. Backend: /sira/input → forwardToN8N(body)
5. forwardToN8N: POST zu N8N_TASK_URL
6. FastAPI: /webhook/sira3-tasks-create → Gmail API
7. Response: {"ok": true, "data": {...}}
8. OpenAI spricht Antwort
```

---

## Implementierte Tools

### Gmail (3)
- ✅ `gmail.send` - Email senden
- ✅ `gmail.reply` - In Thread antworten
- ✅ `gmail.get` - Emails abrufen

### Calendar (4)
- ✅ `calendar.free_slots` - Freie Zeiten finden
- ✅ `calendar.create` - Termin erstellen
- ✅ `calendar.update` - Termin aktualisieren
- ✅ `calendar.list` - Termine auflisten

### Contacts (2)
- ✅ `contacts.find` - Kontakte suchen
- ✅ `contacts.upsert` - Kontakt erstellen/aktualisieren

### Web & Search (2)
- ✅ `web.search` - Google-Suche (SerpAPI)
- ✅ `web.fetch` - Webseite abrufen

### Productivity (2)
- ✅ `notes.log` - Notiz speichern
- ✅ `reminder.set` - Erinnerung erstellen (Google Tasks)

### Phone (1)
- ✅ `phone.call` - Anruf tätigen (Twilio)

### Noch zu implementieren (3)
- ⏳ `news.get` - Nachrichten abrufen
- ⏳ `weather.get` - Wetter-Vorhersage
- ⏳ `perplexity.search` - Intelligente Suche

---

## OAuth2 Setup

**Einmalig durchführen:**
```
http://localhost:8791/auth/google
```

**Credentials werden gespeichert in:**
```
/app/data/google_token.json
```

**Scopes:**
- Gmail (modify)
- Calendar (full access)
- Contacts (full access)
- Tasks (full access)
- Sheets (full access)

---

## Troubleshooting

### Container startet nicht
```bash
docker logs sira_api_v3
```

### OAuth2 Fehler
```bash
# Token löschen und neu autorisieren
rm ~/Desktop/CascadeProjects/wind/sira_api_v3/data/google_token.json
```

### Realtime Voice funktioniert nicht
```bash
# Prüfe N8N_TASK_URL
docker exec siranet env | grep N8N_TASK_URL

# Sollte sein:
N8N_TASK_URL=http://sira_api_v3:8791/webhook/sira3-tasks-create
```

### Tool-Call schlägt fehl
```bash
# Teste direkt:
curl -X POST http://localhost:8791/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{"tool": "gmail.send", "to": [{"email": "test@example.com"}], "subject": "Test", "body": "Hi"}'
```

---

## Production Deployment (Coolify)

### 1. Git Push
```bash
cd ~/Desktop/CascadeProjects/windsurf-project
git add .
git commit -m "feat: integrate FastAPI tool layer (replaces n8n)"
git push origin main
```

### 2. Coolify Deployment
- Auto-Deploy triggert
- Oder manuell in Coolify UI

### 3. Environment Variables
In Coolify `.env` setzen:
```bash
N8N_TASK_URL=http://sira_api_v3:8791/webhook/sira3-tasks-create
```

### 4. OAuth2 auf Production
```
https://sira.theaigency.ch/auth/google
```

**Redirect URI in Google Cloud Console:**
```
https://sira.theaigency.ch/auth/google/callback
```

---

## Vorteile gegenüber n8n

1. ✅ **Schneller**: Direkte API-Calls statt Webhook-Proxy
2. ✅ **Zuverlässiger**: Keine n8n-Abhängigkeit
3. ✅ **Besser wartbar**: Python Code statt n8n Workflows
4. ✅ **Type-Safe**: Pydantic Validation
5. ✅ **Testbar**: Unit Tests möglich
6. ✅ **Dokumentiert**: Swagger UI (`/docs`)
7. ✅ **Modular**: Einfach neue Tools hinzufügen

---

## Nächste Schritte

- [ ] News API implementieren
- [ ] Weather API implementieren
- [ ] Perplexity API implementieren
- [ ] Unit Tests schreiben
- [ ] Production Deployment
- [ ] Monitoring einrichten

---

**Erstellt von**: Cascade AI  
**Projekt**: Sira Voice Assistant  
**Version**: 3.0 (FastAPI Integration)
