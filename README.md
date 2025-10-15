# Sira-Voice - KI-Assistentin mit Realtime Audio

Deutschsprachige KI-Assistentin mit OpenAI Realtime API, Redis Memory und n8n Integration.

## Features

- 🎙️ **Realtime Audio** - Spracheingabe/-ausgabe mit OpenAI Realtime API
- 🧠 **Redis Memory** - Gespräche werden gespeichert und erinnert
- 📧 **n8n Integration** - E-Mail-Versand und Automationen
- 🎨 **Modernes UI** - PWA-fähig, Neon-Grün Design
- 🔒 **Sicher** - Token-basierte Authentifizierung, CORS-Support

## Tech Stack

- **Backend**: Node.js (Alpine)
- **AI**: OpenAI GPT-4o + Realtime API
- **Memory**: Redis
- **Vector DB**: Qdrant (optional)
- **Automation**: n8n
- **Deployment**: Docker / Coolify

## Deployment auf Coolify

1. **Repository verbinden** in Coolify
2. **Umgebungsvariablen** setzen (siehe `.env.example`)
3. **Services anlegen**:
   - Redis (Port 6379)
   - Qdrant (Port 6333, optional)
   - SiraNet (Dockerfile)
4. **Domain verbinden** und SSL aktivieren

## Lokale Entwicklung

```bash
# Docker Compose starten
docker-compose up -d

# App öffnen
open http://localhost:8787/sira/rt/v2/ptt
```

## Umgebungsvariablen

Siehe `.env.example` für alle erforderlichen Variablen.

Wichtigste:
- `OPENAI_API_KEY` - OpenAI API Key
- `REDIS_URL` - Redis Connection String
- `N8N_TASK_URL` - n8n Webhook URL
- `SIRA_MEM_AUTOSAVE=1` - Memory aktivieren

## Lizenz

Proprietär - the aigency
