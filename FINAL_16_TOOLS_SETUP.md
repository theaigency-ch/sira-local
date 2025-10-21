# Sira 3.0 - Finale 16 Tools Setup

## 🎯 Komplette Tool-Übersicht

### **Gmail Suite (3 Tools)**
1. ✅ gmail.send - Email senden
2. ✅ gmail.reply - In Thread antworten
3. ✅ **gmail.get** - Emails abrufen (NEU!)

### **Calendar Suite (4 Tools)**
4. ✅ calendar.free_slots - Freie Zeiten finden
5. ✅ calendar.create - Termin erstellen
6. ✅ calendar.update - Termin aktualisieren
7. ✅ **calendar.list** - Termine auflisten (NEU!)

### **Contacts Suite (2 Tools)**
8. ✅ contacts.find - Kontakte suchen
9. ✅ contacts.upsert - Kontakt erstellen/aktualisieren

### **Web & Search (3 Tools)**
10. ✅ web.search - Google-Suche (SerpAPI)
11. ✅ web.fetch - Webseite abrufen
12. ✅ perplexity.search - Intelligente Suche

### **News & Weather (2 Tools)**
13. ✅ news.get - Aktuelle Nachrichten
14. ✅ weather.get - Wetter-Vorhersage

### **Productivity (2 Tools)**
15. ✅ notes.log - Notiz speichern
16. ✅ **reminder.set** - Erinnerung erstellen (NEU!)

---

## 🆕 Neue Tools im Detail

### 14. **gmail.get** - Emails abrufen

**Request:**
```json
{
  "tool": "gmail.get",
  "filter": "is:unread",
  "limit": 5
}
```

**Filter-Optionen:**
- `is:unread` - Nur ungelesene Mails
- `from:peter@example.com` - Von bestimmter Person
- `subject:Meeting` - Mit bestimmtem Betreff
- `after:2025/10/20` - Nach Datum
- `has:attachment` - Mit Anhang

**Response:**
```json
{
  "ok": true,
  "count": 3,
  "emails": [
    {
      "id": "msg_123",
      "threadId": "thread_456",
      "from": "Peter Baka <pbaka@bluewin.ch>",
      "subject": "Meeting morgen",
      "snippet": "Können wir das Meeting...",
      "date": "Mon, 21 Oct 2025 10:30:00",
      "unread": true
    }
  ]
}
```

**Use Cases:**
```
User: "Habe ich neue Mails?"
User: "Zeig mir Mails von Peter"
User: "Ungelesene Mails mit Anhang"
```

---

### 15. **calendar.list** - Termine auflisten

**Request:**
```json
{
  "tool": "calendar.list",
  "date": "today",
  "limit": 10
}
```

**Date-Optionen:**
- `today` - Heute
- `tomorrow` - Morgen
- `this_week` - Diese Woche
- `2025-10-25` - Bestimmtes Datum

**Response:**
```json
{
  "ok": true,
  "count": 2,
  "events": [
    {
      "id": "event_123",
      "summary": "Team Meeting",
      "start": "2025-10-21T14:00:00Z",
      "end": "2025-10-21T15:00:00Z",
      "location": "Zoom",
      "description": "Wöchentliches Sync"
    }
  ]
}
```

**Use Cases:**
```
User: "Was steht heute an?"
User: "Meine Termine morgen"
User: "Was habe ich diese Woche?"
```

---

### 16. **reminder.set** - Erinnerung erstellen

**Request:**
```json
{
  "tool": "reminder.set",
  "title": "Peter anrufen",
  "date": "2025-10-22T14:00:00",
  "notes": "Wegen Projekt besprechen"
}
```

**Response:**
```json
{
  "ok": true,
  "id": "task_123",
  "title": "Peter anrufen",
  "due": "2025-10-22T14:00:00"
}
```

**Use Cases:**
```
User: "Erinnere mich morgen um 14 Uhr Peter anzurufen"
User: "Setze eine Erinnerung für Freitag"
User: "Merke dir: Dokument bis Montag fertig"
```

---

## 🔑 Neue Credentials

### Google Tasks OAuth2 (für reminder.set)

**Schritt 1: Google Cloud Console**
1. Gehe zu: https://console.cloud.google.com
2. Projekt auswählen (oder neues erstellen)
3. APIs & Services → Library
4. Suche: "Google Tasks API"
5. Klicke "Enable"

**Schritt 2: OAuth Credentials**
1. APIs & Services → Credentials
2. Nutze bestehende OAuth2 Credentials (gleiche wie Gmail/Calendar)
3. Oder erstelle neue: "Create Credentials" → "OAuth 2.0 Client ID"

**Schritt 3: n8n Credential**
1. n8n UI → Credentials → + Add Credential
2. Wähle: **Google Tasks OAuth2 API**
3. Konfiguriere:
   ```
   Name: Google Tasks account
   Client ID: [Aus Google Cloud Console]
   Client Secret: [Aus Google Cloud Console]
   ```
4. Klicke "Connect my account"
5. Autorisiere mit Google
6. Save

---

## 🧪 Tests

```bash
# Test 1: Ungelesene Mails
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "gmail.get",
    "filter": "is:unread",
    "limit": 5
  }'

# Test 2: Mails von bestimmter Person
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "gmail.get",
    "filter": "from:pbaka@bluewin.ch",
    "limit": 3
  }'

# Test 3: Termine heute
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "calendar.list",
    "date": "today"
  }'

# Test 4: Termine diese Woche
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "calendar.list",
    "date": "this_week",
    "limit": 20
  }'

# Test 5: Erinnerung setzen
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "reminder.set",
    "title": "Test-Erinnerung",
    "date": "2025-10-22T14:00:00",
    "notes": "Dies ist ein Test"
  }'
```

---

## 🎯 Sira Integration - Beispiele

### 1. Morgen-Briefing (erweitert)

```javascript
async function getMorningBriefing() {
  // Wetter
  const weather = await forwardToN8N({
    tool: 'weather.get',
    location: 'Zürich',
    days: 1
  });
  
  // News
  const news = await forwardToN8N({
    tool: 'news.get',
    category: 'schweiz',
    limit: 3
  });
  
  // Ungelesene Mails
  const emails = await forwardToN8N({
    tool: 'gmail.get',
    filter: 'is:unread',
    limit: 5
  });
  
  // Termine heute
  const events = await forwardToN8N({
    tool: 'calendar.list',
    date: 'today'
  });
  
  return `
Guten Morgen! ☀️

**Wetter:** ${weather.current.temp}°C in Zürich, ${weather.current.condition}

**Termine heute:** ${events.count} Termine
${events.events.map(e => `- ${e.start.split('T')[1].slice(0,5)}: ${e.summary}`).join('\n')}

**Ungelesene Mails:** ${emails.count} neue Mails
${emails.emails.slice(0,3).map(e => `- ${e.from.split('<')[0]}: ${e.subject}`).join('\n')}

**News:** ${news.summary}
  `.trim();
}
```

### 2. Email-Check

```javascript
// User: "Habe ich neue Mails?"
if (userQ.match(/neue? mail|ungelesen|inbox/i)) {
  const emails = await forwardToN8N({
    tool: 'gmail.get',
    filter: 'is:unread',
    limit: 5
  });
  
  if (emails.count === 0) {
    return "Keine neuen Mails! 📭";
  }
  
  return `Du hast ${emails.count} ungelesene Mails:\n` +
    emails.emails.map((e, i) => 
      `${i+1}. ${e.from.split('<')[0]}: ${e.subject}`
    ).join('\n');
}
```

### 3. Tagesplanung

```javascript
// User: "Was steht heute an?"
if (userQ.match(/was steht.*an|termine heute|tagesplan/i)) {
  const events = await forwardToN8N({
    tool: 'calendar.list',
    date: 'today'
  });
  
  if (events.count === 0) {
    return "Heute keine Termine! 🎉";
  }
  
  return `Heute hast du ${events.count} Termine:\n` +
    events.events.map(e => {
      const time = e.start.split('T')[1].slice(0,5);
      return `- ${time}: ${e.summary}${e.location ? ' (' + e.location + ')' : ''}`;
    }).join('\n');
}
```

### 4. Erinnerung setzen

```javascript
// User: "Erinnere mich morgen um 14 Uhr Peter anzurufen"
if (userQ.match(/erinner.*mich|reminder|merke dir/i)) {
  // Parse Intent
  const timeMatch = userQ.match(/(\d{1,2}):?(\d{2})?\s*uhr/i);
  const dateMatch = userQ.match(/morgen|übermorgen|montag|dienstag/i);
  const taskMatch = userQ.match(/(?:erinner.*mich|reminder)\s+(.+?)(?:\s+um|\s+morgen|$)/i);
  
  const reminder = await forwardToN8N({
    tool: 'reminder.set',
    title: taskMatch ? taskMatch[1] : 'Erinnerung',
    date: calculateDate(dateMatch, timeMatch),
    notes: userQ
  });
  
  return `✅ Erinnerung gesetzt: ${reminder.title} am ${reminder.due}`;
}
```

---

## 📊 Komplette Tool-Matrix

| Kategorie | Tools | Status |
|-----------|-------|--------|
| **Gmail** | send, reply, get | ✅ Komplett |
| **Calendar** | free_slots, create, update, list | ✅ Komplett |
| **Contacts** | find, upsert | ✅ Komplett |
| **Web** | search, fetch, perplexity | ✅ Komplett |
| **News & Weather** | news, weather | ✅ Komplett |
| **Productivity** | notes, reminder | ✅ Komplett |

**Total: 16 Tools** 🎯

---

## 💰 Kosten (aktualisiert)

| Service | Kosten/Monat |
|---------|--------------|
| Gmail, Calendar, Contacts, Sheets, Tasks | ✅ Kostenlos |
| SerpAPI | $50 (5000 searches) |
| Perplexity | ~$3-5 |
| OpenWeather | ✅ Kostenlos |
| **Total** | ~$53-55/Monat |

---

## ✅ Setup-Checkliste

- [ ] Workflow importiert: `sira-n8n-final-COMPLETE.json`
- [ ] Gmail OAuth2 verbunden
- [ ] Google Calendar OAuth2 verbunden
- [ ] Google Contacts OAuth2 verbunden
- [ ] Google Sheets OAuth2 verbunden
- [ ] **Google Tasks OAuth2 verbunden** (NEU!)
- [ ] SerpAPI Key verbunden
- [ ] Perplexity API Key verbunden
- [ ] OpenWeather API Key verbunden
- [ ] Alle 16 Tools getestet

---

**Sira ist jetzt KOMPLETT ausgestattet mit 16 essentiellen Tools!** 🎉✨

**Erstellt:** 21.10.2025 11:33 Uhr  
**Status:** Production Ready  
**Datei:** `sira-n8n-final-COMPLETE.json`
