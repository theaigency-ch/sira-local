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
- `N8N_TASK_URL` - n8n Webhook für Aktionen
- `SIRA_TOKEN` - API-Token für Endpoints
- `SIRA_PRIVATE_EMAIL` - User private Email
- `SIRA_WORK_EMAIL` - User work Email

## Letzte Änderungen

### 16.10.2025 - Memory Loss Fix (HEUTE)
- **Problem:** Daten wurden verloren wenn Qdrant-Archivierung fehlschlug
- **Dateien:** Dockerfile, MEMORY_LOSS_FIX.md, verify-memory-fix.sh, PROJECT_CONTEXT.md
- **Status:** Lokal getestet ✓, Container neu gebaut ✓, noch NICHT auf Coolify deployed
- **Nächster Schritt:** Git commit + push zu GitHub → Coolify Auto-Deploy

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
- **Letzte Session:** 15.10.2025 (Bulk Facts Import, Memory-Tests)
- **Aktuelle Session:** 16.10.2025 (Memory Loss Fix)

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

## Was heute (16.10.) gemacht wurde

1. **Memory Loss Problem identifiziert:**
   - User berichtete: Nur letzte Aktion verfügbar, Rest verloren
   - Root Cause: Qdrant Collections fehlten, Archivierung löschte Daten trotzdem
   
2. **Fixes implementiert:**
   - Robuste Qdrant-Initialisierung (30s Retry)
   - Sichere Archivierung (keine Datenlöschung bei Fehler)
   - Verbesserte Fehlerbehandlung & Logging
   
3. **Dokumentation erstellt:**
   - `MEMORY_LOSS_FIX.md` - Detaillierte Analyse
   - `verify-memory-fix.sh` - Verifikations-Skript
   - `PROJECT_CONTEXT.md` - Diese Datei (für AI-Assistenten)
   
4. **Status:** Lokal getestet ✓, noch NICHT deployed

## TODO / Offene Punkte

- [ ] **JETZT:** Memory Loss Fix committen & pushen
- [ ] Coolify Auto-Deploy verifizieren
- [ ] Qdrant Collections auf VPS prüfen/erstellen (falls nötig)
- [ ] Nach Deployment: Verlorene Fakten neu eingeben
- [ ] Backup-Strategie für Redis implementieren
- [ ] Monitoring einrichten

---

**Für AI-Assistenten:**
1. Diese Datei am Anfang JEDER Session lesen
2. Bei Deployment-Fragen: Deployment-Workflow oben folgen
3. Bei Memory-Problemen: MEMORY_LOSS_FIX.md lesen
4. Vor Git-Befehlen: `git status` und `git remote -v` prüfen
5. Diese Datei aktualisieren wenn wichtige Änderungen gemacht werden
