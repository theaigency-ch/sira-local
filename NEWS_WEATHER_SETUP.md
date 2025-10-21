# News & Weather Setup für Sira

## 🔑 API Keys erstellen

### 1. OpenWeather API (Kostenlos!)

**Schritt 1: Account erstellen**
1. Gehe zu: https://openweathermap.org/api
2. Klicke "Sign Up"
3. Bestätige Email

**Schritt 2: API Key generieren**
1. Gehe zu: https://home.openweathermap.org/api_keys
2. Kopiere den "Default" API Key
3. Oder erstelle neuen: "Create Key" → Name: "Sira"

**Schritt 3: n8n Credential**
1. n8n UI → Credentials → + Add Credential
2. Wähle: **Query Auth**
3. Konfiguriere:
   ```
   Name: OpenWeather API
   Query Parameter Name: appid
   Query Parameter Value: DEIN_API_KEY_HIER
   ```
4. Save

**Kosten:** ✅ **KOSTENLOS** (1000 calls/Tag)

---

### 2. Perplexity API (bereits vorhanden)

Falls noch nicht erstellt:
1. https://www.perplexity.ai/settings/api
2. Generate API Key
3. n8n Credential: "Perplexity API" (siehe PERPLEXITY_SETUP.md)

---

## 📊 Verfügbare Tools

### 1. **news.get** - Aktuelle Nachrichten

**Kategorien:**
- `schweiz` - Schweizer News (Standard)
- `international` - Weltnachrichten
- `tech` - Technologie
- `business` - Wirtschaft

**Request:**
```json
{
  "tool": "news.get",
  "category": "schweiz",
  "limit": 5
}
```

**Response:**
```json
{
  "ok": true,
  "category": "schweiz",
  "summary": "Heute in der Schweiz: Die Nationalbank senkt den Leitzins...",
  "sources": [
    "https://www.nzz.ch/...",
    "https://www.srf.ch/..."
  ]
}
```

---

### 2. **weather.get** - Wetter-Vorhersage

**Locations:**
- Zürich, Bern, Basel, Genf, Luzern, etc.
- Internationale Städte möglich

**Request:**
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
      "condition": "Sonnig",
      "humidity": 55,
      "wind": 8
    },
    {
      "date": "2025-10-23",
      "temp_min": 12,
      "temp_max": 20,
      "condition": "Teilweise bewölkt",
      "humidity": 60,
      "wind": 10
    }
  ]
}
```

---

## 🧪 Tests

```bash
# Test 1: Schweizer News
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "news.get",
    "category": "schweiz",
    "limit": 5
  }'

# Test 2: Tech News
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "news.get",
    "category": "tech",
    "limit": 3
  }'

# Test 3: Wetter Zürich
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "weather.get",
    "location": "Zürich",
    "days": 3
  }'

# Test 4: Wetter International
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "weather.get",
    "location": "New York",
    "days": 5
  }'
```

---

## 🎯 Sira Integration - Morgen-Briefing

### Beispiel: Automatisches Morgen-Briefing

```javascript
// In Sira's Dockerfile
async function getMorningBriefing() {
  // Wetter abrufen
  const weather = await forwardToN8N({
    tool: 'weather.get',
    location: 'Zürich',
    days: 1
  });
  
  // News abrufen
  const news = await forwardToN8N({
    tool: 'news.get',
    category: 'schweiz',
    limit: 3
  });
  
  // Briefing zusammenstellen
  const briefing = `
Guten Morgen! ☀️

**Wetter in Zürich:**
Aktuell ${weather.current.temp}°C, ${weather.current.condition}.
Heute zwischen ${weather.forecast[0].temp_min}°C und ${weather.forecast[0].temp_max}°C.

**Nachrichten:**
${news.summary}

Quellen: ${news.sources.slice(0, 2).join(', ')}
  `.trim();
  
  return briefing;
}
```

### Verwendung in Sira:

```javascript
// User fragt: "Was gibt's Neues?"
if (userQ.match(/was gibt.?s neu|morgen briefing|news|nachrichten/i)) {
  const briefing = await getMorningBriefing();
  return { ok: true, text: briefing };
}
```

---

## 📋 Use Cases

### 1. **Tägliches Briefing**
```
User: "Guten Morgen Sira, was gibt's Neues?"
Sira: [Ruft news.get + weather.get auf]
      "Guten Morgen! 15°C in Zürich, bewölkt.
       Heute in den News: Die Nationalbank..."
```

### 2. **Wetter-Check**
```
User: "Wie wird das Wetter morgen?"
Sira: [Ruft weather.get auf]
      "Morgen in Zürich: 10-18°C, sonnig.
       Perfekt für einen Spaziergang!"
```

### 3. **News-Kategorie**
```
User: "Was gibt's Neues in der Tech-Welt?"
Sira: [Ruft news.get mit category=tech auf]
      "Heute in Tech: OpenAI kündigt..."
```

### 4. **Reise-Planung**
```
User: "Wie ist das Wetter in Paris nächste Woche?"
Sira: [Ruft weather.get mit location=Paris auf]
      "Nächste Woche in Paris: 12-20°C..."
```

---

## 💰 Kosten-Übersicht

| Service | Kosten | Limit |
|---------|--------|-------|
| **OpenWeather** | ✅ Kostenlos | 1000 calls/Tag |
| **Perplexity (News)** | ~$0.001/request | Unbegrenzt |

**Bei 100 News-Abfragen/Tag:**
- OpenWeather: $0
- Perplexity: ~$3/Monat
- **Total: ~$3/Monat**

---

## 🔧 Erweiterte Konfiguration

### News-Kategorien anpassen:

Im "Prep News" Node kannst du weitere Kategorien hinzufügen:

```javascript
// Beispiel: Sport-News
else if(category === 'sport') {
  query = 'Aktuelle Sport-Nachrichten Schweiz heute, Top ' + limit;
}
// Beispiel: Politik
else if(category === 'politik') {
  query = 'Wichtigste politische Entwicklungen Schweiz heute, Top ' + limit;
}
```

### Wetter-Einheiten ändern:

Im "OpenWeather API" Node:
- `units=metric` → Celsius (Standard)
- `units=imperial` → Fahrenheit
- `lang=de` → Deutsch (Standard)
- `lang=en` → Englisch

---

## ✅ Checkliste

- [ ] OpenWeather Account erstellt
- [ ] OpenWeather API Key kopiert
- [ ] n8n Credential "OpenWeather API" erstellt
- [ ] Perplexity API bereits vorhanden
- [ ] Workflow importiert
- [ ] Credentials im Workflow verbunden
- [ ] News-Test durchgeführt
- [ ] Wetter-Test durchgeführt
- [ ] Sira's Morgen-Briefing implementiert

---

## 🔗 Wichtige Links

- **OpenWeather API:** https://openweathermap.org/api
- **OpenWeather Docs:** https://openweathermap.org/forecast5
- **Perplexity API:** https://docs.perplexity.ai
- **n8n Credentials:** https://n8n.theaigency.ch/credentials

---

**Erstellt:** 21.10.2025 11:25 Uhr  
**Status:** Ready to Setup  
**Kosten:** ~$3/Monat (nur Perplexity, OpenWeather kostenlos!)
