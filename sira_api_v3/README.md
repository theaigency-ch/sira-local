# sira_api_v3

FastAPI backend that **replaces n8n** as the tool layer for SiraNet. Provides direct Google API integration (Gmail, Calendar, Contacts, Tasks, Sheets) plus SerpAPI, Twilio, and web fetching.

**Primary Interface**: n8n-compatible webhook endpoint at `/webhook/sira3-tasks-create`

## Quickstart

```bash
cp .env.example .env  # fill in API keys and secrets
docker-compose up --build
```

The API becomes available on `http://localhost:8791` with documentation at `http://localhost:8791/docs`.

## Local development

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8791
```

## Primary Endpoint (n8n-compatible)

**Webhook**: `POST /webhook/sira3-tasks-create`

Receives tool execution requests from SiraNet:
```json
{
  "tool": "gmail.send",
  "to": [{"email": "user@example.com"}],
  "subject": "Test",
  "body": "Hello"
}
```

Returns:
```json
{
  "ok": true,
  "data": {"messageId": "...", "threadId": "..."}
}
```

**Supported tools**: `gmail.send`, `gmail.reply`, `gmail.get`, `calendar.free_slots`, `calendar.create`, `calendar.update`, `calendar.list`, `contacts.find`, `contacts.upsert`, `web.search`, `web.fetch`, `notes.log`, `reminder.set`, `phone.call`

## Alternative REST Endpoints

All endpoints are also available under `/api/v1` for direct access:

- `POST /api/v1/email/send`
- `POST /api/v1/email/reply`
- `POST /api/v1/email/list`
- `POST /api/v1/calendar/free-slots`
- `POST /api/v1/calendar/create`
- `POST /api/v1/calendar/update`
- `POST /api/v1/calendar/list`
- `POST /api/v1/contacts/find`
- `POST /api/v1/contacts/upsert`
- `POST /api/v1/search/web`
- `POST /api/v1/search/fetch`
- `POST /api/v1/search/perplexity`
- `POST /api/v1/news/get`
- `POST /api/v1/weather/get`
- `POST /api/v1/notes/log`
- `POST /api/v1/reminder/set`
- `POST /api/v1/phone/call` (Twilio)
- `GET /api/v1/phone/status` (Twilio)

Each endpoint executes the tool directly via Google APIs, SerpAPI, or Twilio SDK. Responses return `{ "ok": true, "data": ... }` with the execution result.

## Testing

Add tests in `tests/` and execute via:

```bash
pytest
```

## Environment variables

Key values (see `.env.example`):

- `REDIS_URL` (points to existing SiraNet Redis)
- `QDRANT_URL` (points to existing SiraNet Qdrant)
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_PROJECT_ID` (OAuth2)
- `SERPAPI_API_KEY` (web search)
- `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`, `SIRA_PHONE_ENABLED` (phone calls)
