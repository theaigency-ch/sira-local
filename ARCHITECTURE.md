# 🏗️ Sira API v3 - System-Architektur

**Stand:** 25. Oktober 2025, 18:32 Uhr

---

## 📊 Übersicht

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   Ngrok Tunnel        │
         │   (OAuth2 & API)      │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   VPS 31.97.79.208    │
         │   Port 8792           │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────────────────────────────┐
         │          Docker Network (coolify)             │
         │                                               │
         │  ┌─────────────────────────────────────────┐ │
         │  │  FastAPI Container                      │ │
         │  │  ss4wkgsckcog480o8oosw8wk-162620483172  │ │
         │  │  Port: 8791                             │ │
         │  │  Image: ecf8704b9074bb33...             │ │
         │  └──────┬──────────────────────────────────┘ │
         │         │                                     │
         │         ├──────────────┐                      │
         │         │              │                      │
         │         ▼              ▼                      │
         │  ┌──────────┐   ┌──────────┐                 │
         │  │  Redis   │   │  Qdrant  │                 │
         │  │  (Sira)  │   │ (Vector) │                 │
         │  └──────────┘   └──────────┘                 │
         │                                               │
         └───────────────────────────────────────────────┘
```

---

## 🔧 Komponenten

### **1. FastAPI Application**
- **Container:** `ss4wkgsckcog480o8oosw8wk-162620483172`
- **Image:** `ss4wkgsckcog480o8oosw8wk:ecf8704b9074bb33fdb50045de26f1b734ed8f2c`
- **Port:** 8791 (intern), 8792 (extern)
- **Framework:** FastAPI + Uvicorn
- **Python:** 3.11-slim
- **Deployment:** Coolify (automatisch via GitHub)

**Hauptfunktionen:**
- OAuth2 Authentication (Google)
- Gmail API Integration
- Google Calendar API Integration
- Google Contacts API Integration
- SerpAPI Web Search
- REST API Endpoints

### **2. Redis (Token Storage)**
- **Container:** `redis-sira-hcs08c84g0o0sc8wwkg4ssk4`
- **Image:** `redis:7-alpine`
- **Port:** 6379 (intern)
- **Funktion:** OAuth Token Persistenz
- **Key:** `google:oauth_token`

**Gespeicherte Daten:**
- OAuth Access Tokens
- OAuth Refresh Tokens
- Token Metadata (Client ID, Scopes, etc.)

### **3. Qdrant (Vector Database)**
- **Container:** `qdrant-tkg0g80o4owc00w0oko4sg80`
- **Image:** `qdrant/qdrant:latest`
- **Port:** 6333-6334
- **Status:** Unhealthy (aber funktioniert)
- **Funktion:** Vector Search (zukünftig)

### **4. Ngrok (Public Access)**
- **URL:** `https://nonradioactive-margrett-supersolar.ngrok-free.dev`
- **Funktion:** OAuth2 Callback & API Zugriff
- **Port:** 8792 → FastAPI
- **Hinweis:** URL ändert sich bei Neustart

### **5. Coolify (Deployment Platform)**
- **Version:** v4.0.0-beta.434
- **Funktion:** Container-Orchestrierung
- **Features:**
  - Automatisches Deployment via GitHub
  - Environment Variables Management
  - Container Lifecycle Management
  - Logging & Monitoring

---

## 🔄 Datenfluss

### **OAuth2 Flow:**
```
1. User → /auth/google
2. FastAPI → Google OAuth (Redirect)
3. User → Google Login
4. Google → FastAPI /auth/google/callback (via Ngrok)
5. FastAPI → Tokens speichern in Redis
6. Redis → Persistente Speicherung
```

### **API Request Flow:**
```
1. Client → Ngrok URL
2. Ngrok → VPS Port 8792
3. Docker → FastAPI Container Port 8791
4. FastAPI → Redis (Token abrufen)
5. FastAPI → Google API (mit Token)
6. Google API → Response
7. FastAPI → Client (via Ngrok)
```

### **Token Refresh Flow:**
```
1. FastAPI → Token aus Redis laden
2. FastAPI → Token abgelaufen?
3. FastAPI → Google Token Refresh
4. FastAPI → Neuen Token in Redis speichern
5. FastAPI → API Request mit neuem Token
```

---

## 🔐 Sicherheit

### **Secrets Management:**
- ✅ Environment Variables in Coolify
- ✅ Keine Secrets in Git
- ✅ Tokens nur in Redis (nicht in Dateien)
- ✅ Redis nur intern erreichbar

### **OAuth2 Scopes:**
```
- https://www.googleapis.com/auth/gmail.modify
- https://www.googleapis.com/auth/calendar
- https://www.googleapis.com/auth/contacts
- https://www.googleapis.com/auth/tasks
- https://www.googleapis.com/auth/spreadsheets
```

---

## 📡 API Endpoints

### **Authentication:**
- `GET /auth/google` - Start OAuth Flow
- `GET /auth/google/callback` - OAuth Callback

### **Email (Gmail):**
- `POST /api/v1/email/send` - Email senden
- `POST /api/v1/email/reply` - Email beantworten
- `POST /api/v1/email/list` - Emails auflisten

### **Calendar:**
- `POST /api/v1/calendar/create` - Event erstellen
- `POST /api/v1/calendar/update` - Event aktualisieren
- `POST /api/v1/calendar/list` - Events auflisten
- `POST /api/v1/calendar/free-slots` - Freie Slots finden

### **Contacts:**
- `POST /api/v1/contacts/find` - Kontakte suchen
- `POST /api/v1/contacts/upsert` - Kontakt erstellen/aktualisieren

### **Search:**
- `POST /api/v1/search/web` - Web Search (SerpAPI)
- `POST /api/v1/search/perplexity` - Perplexity Search (nicht implementiert)

### **Other:**
- `POST /api/v1/news/get` - News abrufen (nicht konfiguriert)
- `POST /api/v1/weather/get` - Wetter abrufen (nicht konfiguriert)
- `POST /api/v1/phone/call` - Anruf tätigen (Twilio, nicht konfiguriert)

---

## 🚀 Deployment-Prozess

### **Automatisches Deployment:**
```
1. Code ändern lokal
2. git commit -m "message"
3. git push origin main
4. GitHub → Webhook → Coolify
5. Coolify → Docker Image bauen
6. Coolify → Alter Container stoppen
7. Coolify → Neuer Container starten
8. Tokens bleiben in Redis erhalten ✅
```

### **Manuelles Deployment:**
```
1. Coolify → Applications
2. theaigency-ch/sira-local auswählen
3. "Redeploy" Button klicken
4. Warten bis "Deployment is Finished"
```

---

## 🔧 Wartung

### **Logs prüfen:**
```bash
ssh root@31.97.79.208
docker logs ss4wkgsckcog480o8oosw8wk-162620483172
```

### **Redis Tokens prüfen:**
```bash
docker exec redis-sira-hcs08c84g0o0sc8wwkg4ssk4 \
  redis-cli -a [PASSWORD] KEYS 'google:*'
```

### **Container Status:**
```bash
docker ps | grep ss4wk
```

---

## 📈 Performance

### **Aktuelle Metriken:**
- **Response Time:** < 500ms (Gmail API)
- **Uptime:** 99%+ (Coolify managed)
- **Token Refresh:** Automatisch
- **Container Restarts:** Keine Auswirkung auf Tokens

---

## 🎯 Nächste Schritte

### **Kurzfristig:**
- [ ] Ngrok auf paid plan (feste Domain)
- [ ] Traefik-Routing für api.sira.theaigency.ch
- [ ] Monitoring & Alerting

### **Mittelfristig:**
- [ ] Backup-Strategie für Redis
- [ ] Health Check Endpoints
- [ ] Rate Limiting

### **Langfristig:**
- [ ] Horizontal Scaling
- [ ] Load Balancer
- [ ] Production-Grade Logging

---

**Dokumentiert am:** 25. Oktober 2025, 18:32 Uhr
**Version:** 1.0
**Status:** Produktiv
