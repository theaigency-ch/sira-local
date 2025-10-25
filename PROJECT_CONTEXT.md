# Sira Project - Kontext für AI-Assistenten

**WICHTIG: Diese Datei IMMER am Anfang einer Session lesen!**

## Projekt-Übersicht

- **Name:** Sira Voice Assistant
- **Typ:** Realtime Voice AI mit Memory-System
- **Tech Stack:** Node.js, Docker, Redis, Qdrant, OpenAI Realtime API
- **Deployment:** Coolify auf VPS (sira.theaigency.ch)

## Git & Deployment

### Repository
```bash
# Remote:
origin: https://github.com/theaigency-ch/sira-local.git

# Branch:
main (aktiv)

# Deployment-Methode:
Git Push → GitHub → Coolify Auto-Deploy
```

### Deployment-Workflow
1. Änderungen lokal testen
2. `git add .`
3. `git commit -m "..."`
4. `git push origin main`
5. Coolify deployed automatisch (oder manuell triggern)

### Wichtige Befehle
```bash
# Lokal testen:
docker-compose build --no-cache siranet
docker-compose up -d

# Deployment (falls manuell):
./deploy-to-vps.sh  # (VPS_HOST muss konfiguriert sein)
```

## Architektur

### Container
- **siranet** - Haupt-App (Port 8787)
- **redis-sira** - Memory-Speicher
- **qdrant** - Vektor-Datenbank für Facts & archivierte Memories

### Memory-System
- **Redis:** Aktuelle Konversation (sira:memory)
- **Qdrant Collections:**
  - `sira_facts` - Langzeit-Fakten ("Merke dir...")
  - `sira_memory` - Archivierte alte Gespräche (>50k Zeichen)

### Wichtige Endpoints
- `/sira/rt/v2/ptt` - Realtime Voice UI
- `/sira/ask` - Text/TTS Chat
- `/sira/memory` - Memory abrufen
- `/sira/memory/add` - Memory hinzufügen
- `/sira/rt/memory/save` - Realtime-Transkripte speichern
- `/sira/diag` - Diagnose
- `/sira/diag/data` - Redis/Qdrant Status

## Bekannte Probleme & Fixes

### Memory Loss Problem (16.10.2025)
**Problem:** Daten wurden verloren wenn Qdrant-Archivierung fehlschlug
**Fix:** Dockerfile Zeilen 199-224, 259-317
- Daten werden NICHT mehr gelöscht bei fehlgeschlagener Archivierung
- Robuste Qdrant-Initialisierung mit 30s Retry
- Siehe: `MEMORY_LOSS_FIX.md`

## Umgebungsvariablen

Wichtige Env-Vars (in `.env`):
- `OPENAI_API_KEY` - OpenAI API Key
- `REDIS_URL` - redis://redis-sira:6379 (mit Passwort)
- `QDRANT_URL` - http://qdrant:6333
- `N8N_TASK_URL` - FastAPI Tool-Layer URL
  - Intern (Docker-Netz): `http://sira-api-v3:8791/webhook/sira3-tasks-create`
  - Extern (Domain, sobald live): `https://api.sira.theaigency.ch/webhook/sira3-tasks-create`
- `SIRA_TOKEN` - API-Token für Endpoints
- `SIRA_PRIVATE_EMAIL` - User private Email
- `SIRA_WORK_EMAIL` - User work Email

## Letzte Änderungen

### 19.10.2025 - Social Media Automation Projekt (HEUTE)
- **Neues Projekt:** Social Media Automation System erstellt
- **Location:** `/Users/macbookpro/Desktop/CascadeProjects/social-media-automation`
- **Features:**
  - 4 N8N Workflows (Content Generation, A/B Testing, Approval & Publishing, Analytics)
  - 22 Dokumentations-Dateien (260 KB)
  - A/B Testing mit 2 Varianten (Direct vs. Storytelling)
  - Deutscher Sales Pitch
  - Content Recycling Guide
  - Security Checklist (20 Punkte)
  - Analytics Guide (3 Ebenen)
- **Status:** 100% Complete & Ready to Deploy ✓
- **Dokumentation:** COMPLETION_REPORT.txt aktualisiert

### 16.10.2025 - Memory Loss Fix
- **Problem:** Daten wurden verloren wenn Qdrant-Archivierung fehlschlug
- **Dateien:** Dockerfile, MEMORY_LOSS_FIX.md, verify-memory-fix.sh, PROJECT_CONTEXT.md
- **Status:** Deployed auf Coolify ✓

### 15.10.2025 - Bulk Facts Import (GESTERN)
- **Commit:** `93d90e6` - "Feature: Bulk Facts Import Endpoint + sira-facts.md"
- **Features:**
  - `/sira/facts/import` Endpoint für Bulk-Import
  - `sira-facts.md` mit 120 Business-Fakten
  - `import-facts.sh` Skript
- **Status:** Deployed auf Coolify ✓

### 15.10.2025 - Keyword-basiertes Fakten-System (GESTERN)
- **Commits:**
  - `7fa8c47` - Polish: Satzzeichen-Handling
  - `3d2aaba` - Fix: Keyword-Regex verbessert
  - `dbccc71` - Feature: "Merke dir", "Speichere" Keywords
- **Features:**
  - Automatische Erkennung von "Merke dir..." Phrasen
  - Speicherung in Qdrant Facts Collection
  - Semantische Suche in Fakten
- **Status:** Deployed auf Coolify ✓

### 15.10.2025 - Intelligentes Memory-System (GESTERN)
- **Commits:**
  - `c2fa103` - Feature: Qdrant Memory-Archivierung
  - `9c29cae` - Fix: Memory Context 1500→8000 Zeichen
  - `efb1fe1` - Fix: Memory Race Condition
- **Features:**
  - Qdrant Collections: sira_memory, sira_facts
  - Automatische Archivierung bei >50k Zeichen
  - Semantische Suche in alten Gesprächen
  - Memory-Kontext erhöht auf 8000 Zeichen
- **Status:** Deployed auf Coolify ✓
- **Problem:** Archivierung löschte Daten bei Fehler → Fix heute (16.10.)

## Deployment-Checkliste

Vor jedem Deployment:
- [ ] Lokal getestet?
- [ ] Docker-Logs geprüft?
- [ ] Redis funktioniert?
- [ ] Qdrant Collections existieren?
- [ ] Backup erstellt? (optional)

Nach Deployment:
- [ ] Coolify Logs prüfen
- [ ] https://sira.theaigency.ch/sira/rt/v2/ptt testen
- [ ] Memory-Endpoint testen
- [ ] Bei Problemen: Rollback in Coolify

## Wichtige Dateien

- `Dockerfile` - Haupt-Anwendung (single-file Node.js)
- `docker-compose.yml` - Container-Orchestrierung
- `.env` - Umgebungsvariablen (NICHT committen!)
- `deploy-to-vps.sh` - Deployment-Skript
- `test-connections.sh` - Test-Skript
- `verify-memory-fix.sh` - Memory-Fix Verifikation

## Troubleshooting

### Container startet nicht
```bash
docker logs siranet
docker logs redis-sira
docker logs qdrant
```

### Memory funktioniert nicht
```bash
# Redis prüfen
docker exec redis-sira redis-cli -a PASSWORD GET sira:memory

# Qdrant prüfen
curl http://localhost:6333/collections
```

### Deployment schlägt fehl
- Coolify Logs prüfen
- Git-Push erfolgreich?
- Build-Logs in Coolify ansehen
- Rollback zu letzter funktionierender Version

## Kontakt & Notizen

- **User:** Peter Baka, the aigency
- **Firma:** the aigency (KI-Agenten & Automatisierung)
- **Sprache:** Deutsch (Schweiz)
- **Zeitzone:** UTC+02:00
- **Letzte Session:** 19.10.2025 (Social Media Automation Projekt)
- **Aktuelle Session:** 21.10.2025 (Memory-System Testing & Verification)

## Was gestern (15.10.) gemacht wurde

1. **Intelligentes Memory-System implementiert:**
   - Qdrant Vector Database Integration
   - Automatische Archivierung alter Gespräche
   - Semantische Suche in Memories & Facts
   
2. **Keyword-basiertes Fakten-System:**
   - "Merke dir..." / "Speichere..." Erkennung
   - Automatische Speicherung in Qdrant Facts
   - 120 Business-Fakten in `sira-facts.md`
   
3. **Bulk Import Endpoint:**
   - `/sira/facts/import` für Massen-Import
   - `import-facts.sh` Skript erstellt
   
4. **Alles auf Coolify deployed** ✓

## Was heute (19.10.) gemacht wurde

1. **Neues Projekt: Social Media Automation System:**
   - Komplett neues Projekt in `/social-media-automation`
   - 4 N8N Workflows erstellt (67 KB)
   - 22 Dokumentations-Dateien (260 KB)
   
2. **A/B Testing Feature implementiert:**
   - workflow-1b-ab-content-generation.json (22 KB)
   - Variant A: Direct & Action-Oriented
   - Variant B: Storytelling & Value-Driven
   - Automatische Performance-Analyse
   
3. **8 Advanced Guides erstellt:**
   - GOOGLE_SHEET_TEMPLATE.md
   - EXAMPLE_POSTS.md (8 Beispiele)
   - API_LIMITS_GUIDE.md
   - ERROR_HANDLING.md
   - SECURITY_CHECKLIST.md (20 Punkte)
   - CONTENT_RECYCLING_GUIDE.md
   - ANALYTICS_GUIDE.md (3 Ebenen)
   - AB_TESTING_GUIDE.md
   
4. **Deutscher Sales Pitch:**
   - SALES_PITCH.md neu auf Deutsch
   - Schweizer Stil (CHF, "Sie")
   - 8 Funktionen statt 12
   - Gleiche Länge wie Sales Agent Pitch
   
5. **Alle Core-Dateien aktualisiert:**
   - START_HERE.md (4 Workflows, 22 Dateien)
   - INDEX.md (alle Dateien gelistet)
   - README.md (A/B Testing, Content Recycling)
   - PROJECT_SUMMARY.md (4 Workflows, 11 Features)
   
6. **Feature-Vergleich:**
   - Social Media: A/B Testing ✅ (neu implementiert)
   - Sales Agent: AI Lead Scoring ✅ (via Clay, bereits vorhanden)
   - Entscheidung: Kein Duplikat in N8N nötig (Clay macht es besser)

## Was heute (21.10.) gemacht wurde

1. **Memory-System vollständig getestet:**
   - ✅ Langzeitgedächtnis (Qdrant Facts) funktioniert perfekt
   - ✅ Realtime Memory funktioniert perfekt
   - ✅ "Merke dir" Keywords werden erkannt (Text + Voice)
   - ✅ 51 Fakten in Qdrant gespeichert (49 Business + 2 persönliche)
   
2. **n8n Tool-Layer getestet:**
   - ✅ gmail.send funktioniert (200 OK)
   - ⏳ Andere Tools noch zu testen (calendar, contacts, web)
   - ⚠️ n8n zeigt "Node does not have any credentials set"
   
3. **MCP Status geklärt:**
   - ❌ MCP ist NICHT implementiert (nur in IDE)
   - ✅ Alle Tools laufen über n8n Webhooks (Sira3-tasks-create)
   
4. **Dokumentation erstellt:**
   - MEMORY_TEST_REPORT.md mit allen Test-Ergebnissen
   - PROJECT_CONTEXT.md aktualisiert

## Was heute (24.10.) gemacht wurde

1. **FastAPI Tool-Layer integriert und deployed**
   - Ordner `sira_api_v3/` ins Repo aufgenommen
   - Coolify: als Application mit `Base Directory=/sira_api_v3`, `Dockerfile=./Dockerfile`
   - `Ports Exposes=8791`, keine Host-Port-Mappings
   - Health: Uvicorn intern erreichbar (`HTTP 200 OK` auf `127.0.0.1:8791`), Redis/Qdrant verbunden

2. **SiraNet Anbindung umgestellt**
   - `N8N_TASK_URL` auf internen Alias gesetzt: `http://sira-api-v3:8791/webhook/sira3-tasks-create`
   - Damit funktionieren Tool-Calls im Cluster auch ohne öffentliche Domain

3. **Domain & DNS eingerichtet**
   - `api.sira.theaigency.ch` → A-Record auf `31.97.79.208` (Cloudflare)
   - Hinweis: `sslip.io` nicht für Google OAuth zulässig

4. **Offen (heute nicht abgeschlossen)**
   - Traefik/ACME-Routing für `api.sira.theaigency.ch` noch nicht aktiv (externes `https://api.sira.theaigency.ch/docs` liefert Timeout)
   - Nächste Schritte: Redeploy mit Domain-Bindung, ggf. Cloudflare-Proxy testweise aktivieren, Traefik/ACME-Logs prüfen

5. **OAuth2 (geplant, nach Domain-Fix)**
   - Redirect URI: `https://api.sira.theaigency.ch/auth/google/callback`
   - Start: `https://api.sira.theaigency.ch/auth/google`

## TODO / Offene Punkte

### Sira Voice Assistant (PRIORITÄT):
- [ ] **n8n Credentials in UI prüfen** (localhost:5678)
- [ ] Andere n8n Tools testen (calendar, contacts, web)
- [ ] Facts auf VPS importieren (49 Business-Fakten)
- [ ] Realtime Memory auf VPS testen
- [ ] Health-Checks optimieren (Qdrant, n8n)
- [ ] Backup-Strategie für Redis implementieren
- [ ] Monitoring einrichten

### Social Media Automation:
- [ ] v1.5: Content Recycling Workflow automatisieren
- [ ] v1.5: Video/Podcast Transcription
- [ ] v2.0: Engagement Tracking (automatisch)

---

**Für AI-Assistenten:**
1. Diese Datei am Anfang JEDER Session lesen
2. Bei Deployment-Fragen: Deployment-Workflow oben folgen
3. Bei Memory-Problemen: MEMORY_LOSS_FIX.md lesen
4. Vor Git-Befehlen: `git status` und `git remote -v` prüfen
5. Diese Datei aktualisieren wenn wichtige Änderungen gemacht werden
