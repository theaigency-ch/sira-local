# Sira - Komplette Status-Analyse & High-End Roadmap

**Datum:** 21.10.2025 12:30 Uhr  
**Analysiert:** Dockerfile, PROJECT_CONTEXT.md, n8n Workflow

---

## ✅ **Was BEREITS implementiert ist:**

### **1. Voice Interface** ✅ **VORHANDEN!**
```javascript
// Realtime Voice über OpenAI Response API
- Model: gpt-4o-realtime-preview
- Voice: marin
- WebRTC-basiert
- Push-to-Talk UI
- Audio-Transkription (Whisper-1)
- Auto-Save alle 10 Sekunden
```

**Location:** Dockerfile Zeilen 452-935
- `/sira/rt/v2/ptt` - Voice UI
- `/sira/rt/ephemeral` - Session-Erstellung
- Realtime Memory Save

**Status:** ✅ **KOMPLETT IMPLEMENTIERT!**

---

### **2. Multi-Intent Recognition** ✅ **TEILWEISE VORHANDEN**

**Aktuell implementiert:**
```javascript
// Dockerfile Zeile 998-1007
function parseMailIntent(q){
  // Erkennt: "Schick eine Mail an privat/arbeit"
  // Extrahiert: to, subject, text
  // Triggert: n8n gmail.send
}
```

**Was funktioniert:**
- ✅ Email-Intent (privat/arbeit)
- ✅ Web-Intent (__WEB__ URL)
- ✅ Fakt-Speicherung ("Merke dir...")

**Was FEHLT:**
- ❌ Calendar-Intent ("Termin erstellen...")
- ❌ Weather-Intent ("Wie ist das Wetter...")
- ❌ News-Intent ("Was gibt's Neues...")
- ❌ Contacts-Intent ("Suche Kontakt...")

**Lösung:** LLM-basierte Intent-Erkennung (siehe unten)

---

### **3. Context-Aware Memory** ✅ **VORHANDEN!**

```javascript
// Dockerfile Zeilen 360-379
- Qdrant Search für alte Memories (3 relevante)
- Qdrant Search für Facts (3 relevante)
- Redis für aktuelle Konversation (8000 Zeichen)
- Auto-Archivierung bei >50k Zeichen
```

**Status:** ✅ **KOMPLETT!**

---

### **4. Proaktive Features** ⚠️ **TEILWEISE**

**Vorhanden:**
- ✅ Auto-Save Memory (alle 10s in Realtime)
- ✅ Fakt-Erkennung ("Merke dir...")
- ✅ Web-Abruf bei Bedarf

**Fehlt:**
- ❌ Morgen-Briefing (automatisch)
- ❌ Erinnerungen an Termine
- ❌ Ungelesene Mails-Notification

---

### **5. n8n Tool-Layer** ✅ **KOMPLETT!**

**16 Tools implementiert:**
1. gmail.send, gmail.reply, gmail.get
2. calendar.free_slots, calendar.create, calendar.update, calendar.list
3. contacts.find, contacts.upsert
4. web.search, web.fetch, perplexity.search
5. news.get, weather.get
6. notes.log, reminder.set

**Status:** ✅ **KOMPLETT + ERROR-HANDLING!**

---

### **6. Multi-Step Workflows** ❌ **FEHLT**

**Aktuell:**
- Sira führt nur 1 Tool-Call pro Request aus
- Keine Verkettung von Tools

**Beispiel was NICHT geht:**
```
User: "Plane ein Meeting mit Peter nächste Woche"
→ Sira müsste:
  1. contacts.find (Peter)
  2. calendar.free_slots (nächste Woche)
  3. calendar.create (Termin)
  4. gmail.send (Einladung)
→ Aktuell: Nur 1 Schritt möglich
```

---

### **7. Monitoring & Logging** ⚠️ **BASIC**

**Vorhanden:**
- ✅ Console.log für alle Operationen
- ✅ `/sira/diag` - OpenAI Status
- ✅ `/sira/diag/data` - Redis/Qdrant Status
- ✅ `/sira/diag/qdrant` - Collections Info

**Fehlt:**
- ❌ Zentrales Logging (Loki/Grafana)
- ❌ Metrics (Prometheus)
- ❌ Alerting
- ❌ Performance-Tracking

---

### **8. Backup & Recovery** ❌ **FEHLT**

**Aktuell:**
- Keine automatischen Backups
- Keine Disaster Recovery

**Benötigt:**
- Qdrant Backups (täglich)
- Redis Persistence Config
- n8n Workflow Backups

---

### **9. Security** ⚠️ **BASIC**

**Vorhanden:**
- ✅ SIRA_TOKEN für API-Schutz
- ✅ CORS Configuration
- ✅ OAuth2 für Google APIs (in n8n)

**Fehlt:**
- ❌ Rate Limiting
- ❌ Request Validation
- ❌ IP Whitelisting

---

### **10. Multi-Channel** ❌ **FEHLT**

**Aktuell:**
- Nur Voice UI + API

**Fehlt:**
- ❌ Telegram Bot
- ❌ WhatsApp Integration
- ❌ Web Chat UI
- ❌ Email-Interface

---

## 🎯 **Aktueller Status: 7.5/10**

### **Stärken:**
1. ✅ **Voice Interface** - Komplett mit Realtime API
2. ✅ **Memory System** - Qdrant + Redis perfekt
3. ✅ **16 Tools** - Alle wichtigen Services
4. ✅ **Error-Handling** - n8n Workflow robust
5. ✅ **Fakt-Speicherung** - Langzeit-Memory funktioniert

### **Schwächen:**
1. ❌ **Intent Recognition** - Nur Email, nicht Calendar/Weather/etc.
2. ❌ **Multi-Step Workflows** - Keine Tool-Verkettung
3. ❌ **Monitoring** - Kein Grafana/Prometheus
4. ❌ **Backups** - Keine Automatisierung
5. ❌ **Proaktiv** - Kein Morgen-Briefing

---

## 🚀 **High-End Roadmap (8/10 → 10/10)**

### **Phase 1: Production-Ready (Priorität: HOCH)**

#### **1.1 LLM-basierte Intent-Erkennung** ⭐⭐⭐⭐⭐
**Aufwand:** 2-3 Stunden  
**Impact:** Sehr hoch

**Implementierung:**
```javascript
// In Dockerfile nach Zeile 1007 einfügen:
async function parseIntentLLM(userQ){
  const prompt = `
User sagt: "${userQ}"

Erkenne die Absicht und extrahiere Parameter.

Verfügbare Tools:
- gmail.send: {to, subject, text}
- gmail.get: {filter, limit}
- calendar.create: {summary, start, end}
- calendar.list: {date}
- weather.get: {location}
- news.get: {category}
- contacts.find: {query}
- reminder.set: {title, date}
- web.search: {query}

Antwort als JSON:
{
  "tool": "tool_name",
  "params": {...},
  "confidence": 0.0-1.0
}

Wenn keine Absicht erkannt: {"tool": null}
  `;
  
  try{
    const r = await withTimeout(BASE+'/v1/chat/completions',{
      method:'POST',
      headers:{Authorization:'Bearer '+KEY,'content-type':'application/json'},
      body: JSON.stringify({
        model: 'gpt-4o-mini', // Schneller + günstiger
        messages: [{role:'user',content:prompt}],
        response_format: {type: 'json_object'}
      })
    },5000);
    const js = await r.json();
    const result = JSON.parse(js.choices[0].message.content);
    
    if(result.tool && result.confidence > 0.7){
      console.log('[Intent] Erkannt:', result.tool, 'Confidence:', result.confidence);
      return {tool: result.tool, params: result.params};
    }
  }catch(e){
    console.log('[Intent] LLM-Fehler:', e.message);
  }
  return null;
}

// In /sira/ask Endpoint (Zeile 1142) einbauen:
const llmIntent = await parseIntentLLM(q);
if(llmIntent){
  const fwd = await forwardToN8N(llmIntent);
  res.writeHead(fwd.status, {'content-type':fwd.ctype});
  return res.end(fwd.body);
}
```

**Vorteil:**
- ✅ Versteht komplexe Anfragen
- ✅ Alle 16 Tools automatisch erkannt
- ✅ Kein manuelles Regex-Schreiben mehr
- ✅ Kosten: ~$0.0001 per Request (gpt-4o-mini)

---

#### **1.2 Monitoring & Logging** ⭐⭐⭐⭐⭐
**Aufwand:** 4-6 Stunden  
**Impact:** Sehr hoch

**Implementierung:**
```yaml
# docker-compose.yml ergänzen:
services:
  loki:
    image: grafana/loki:latest
    ports: ["3100:3100"]
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml
      - loki-data:/loki
    networks: [sira-network]
  
  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/log:/var/log
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    networks: [sira-network]
  
  grafana:
    image: grafana/grafana:latest
    ports: ["3000:3000"]
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    networks: [sira-network]

volumes:
  loki-data:
  grafana-data:
```

**Vorteil:**
- ✅ Alle Logs zentral
- ✅ Grafana Dashboards
- ✅ Alerting bei Fehlern
- ✅ Performance-Tracking

---

#### **1.3 Backup & Recovery** ⭐⭐⭐⭐
**Aufwand:** 2 Stunden  
**Impact:** Hoch

**Implementierung:**
```bash
# backup-qdrant.sh
#!/bin/bash
BACKUP_DIR="/backups/qdrant"
DATE=$(date +%Y%m%d_%H%M%S)

docker exec qdrant curl -X POST http://localhost:6333/collections/sira_facts/snapshots
docker exec qdrant curl -X POST http://localhost:6333/collections/sira_memory/snapshots

docker cp qdrant:/qdrant/storage $BACKUP_DIR/$DATE

# Alte Backups löschen (älter als 7 Tage)
find $BACKUP_DIR -type d -mtime +7 -exec rm -rf {} \;

echo "Backup erstellt: $BACKUP_DIR/$DATE"
```

```bash
# Cronjob (täglich um 2 Uhr):
0 2 * * * /app/backup-qdrant.sh
```

**Vorteil:**
- ✅ Keine Datenverluste
- ✅ Disaster Recovery
- ✅ Automatisch

---

### **Phase 2: Smart Features (Priorität: MITTEL)**

#### **2.1 Proaktives Morgen-Briefing** ⭐⭐⭐⭐
**Aufwand:** 3-4 Stunden  
**Impact:** Hoch

**Implementierung:**
```javascript
// In Dockerfile ergänzen:
async function generateMorningBriefing(){
  const weather = await forwardToN8N({tool: 'weather.get', location: 'Zürich'});
  const news = await forwardToN8N({tool: 'news.get', category: 'schweiz', limit: 3});
  const emails = await forwardToN8N({tool: 'gmail.get', filter: 'is:unread', limit: 5});
  const events = await forwardToN8N({tool: 'calendar.list', date: 'today'});
  
  const weatherData = JSON.parse(weather.body);
  const newsData = JSON.parse(news.body);
  const emailsData = JSON.parse(emails.body);
  const eventsData = JSON.parse(events.body);
  
  const briefing = `
Guten Morgen! ☀️

**Wetter in Zürich:**
${weatherData.current.temp}°C, ${weatherData.current.condition}
Heute: ${weatherData.forecast[0].temp_min}-${weatherData.forecast[0].temp_max}°C

**Termine heute:** ${eventsData.count}
${eventsData.events.map(e => `- ${e.start.split('T')[1].slice(0,5)}: ${e.summary}`).join('\n')}

**Ungelesene Mails:** ${emailsData.count}
${emailsData.emails.slice(0,3).map(e => `- ${e.from.split('<')[0]}: ${e.subject}`).join('\n')}

**News:**
${newsData.summary.slice(0, 200)}...

Quellen: ${newsData.sources.slice(0,2).join(', ')}
  `.trim();
  
  return briefing;
}

// Cronjob (täglich um 7 Uhr):
// In docker-compose.yml:
services:
  cron:
    image: alpine:latest
    command: >
      sh -c "echo '0 7 * * * curl -X POST http://siranet:8787/sira/briefing/send' | crontab - && crond -f"
    networks: [sira-network]
```

**Vorteil:**
- ✅ Sira wird proaktiv
- ✅ Nutzer bekommt Info ohne Fragen
- ✅ Kann via Email/Telegram gesendet werden

---

#### **2.2 Multi-Step Workflows** ⭐⭐⭐⭐⭐
**Aufwand:** 6-8 Stunden  
**Impact:** Sehr hoch

**Implementierung:**
```javascript
// Workflow-Engine in Dockerfile:
async function executeWorkflow(steps){
  const results = [];
  
  for(const step of steps){
    console.log('[Workflow] Schritt:', step.tool);
    
    // Ersetze Variablen aus vorherigen Schritten
    const params = replaceVariables(step.params, results);
    
    const result = await forwardToN8N({tool: step.tool, ...params});
    results.push({
      tool: step.tool,
      result: JSON.parse(result.body)
    });
    
    // Fehlerbehandlung
    if(!results[results.length-1].result.ok){
      console.log('[Workflow] Fehler bei Schritt:', step.tool);
      return {ok: false, error: 'Workflow failed at ' + step.tool, results};
    }
  }
  
  return {ok: true, results};
}

// Beispiel: "Plane Meeting mit Peter nächste Woche"
const workflow = [
  {tool: 'contacts.find', params: {query: 'Peter'}},
  {tool: 'calendar.free_slots', params: {date: 'next_week', duration: 60}},
  {tool: 'calendar.create', params: {
    summary: 'Meeting mit {{contacts.find.results[0].name}}',
    start: '{{calendar.free_slots.slots[0].start}}',
    end: '{{calendar.free_slots.slots[0].end}}'
  }},
  {tool: 'gmail.send', params: {
    to: '{{contacts.find.results[0].email}}',
    subject: 'Meeting Einladung',
    text: 'Hallo {{contacts.find.results[0].name}}, Meeting am {{calendar.create.start}}'
  }}
];

const result = await executeWorkflow(workflow);
```

**Vorteil:**
- ✅ Komplexe Aufgaben automatisch
- ✅ Sira wird viel intelligenter
- ✅ Nutzer spart Zeit

---

### **Phase 3: Advanced Features (Priorität: NIEDRIG)**

#### **3.1 Multi-Channel (Telegram Bot)** ⭐⭐⭐
**Aufwand:** 8-10 Stunden  
**Impact:** Mittel

**Implementierung:**
```javascript
// telegram-bot.js (neuer Container)
const TelegramBot = require('node-telegram-bot-api');
const bot = new TelegramBot(process.env.TELEGRAM_TOKEN, {polling: true});

bot.on('message', async (msg) => {
  const chatId = msg.chat.id;
  const text = msg.text;
  
  // Sende an Sira
  const response = await fetch('http://siranet:8787/sira/ask', {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({q: text})
  });
  
  const result = await response.json();
  bot.sendMessage(chatId, result.text);
});
```

---

## 📊 **Finale Empfehlung:**

### **Sofort implementieren (1-2 Tage):**
1. ✅ **LLM-basierte Intent-Erkennung** (2-3h)
2. ✅ **Monitoring (Grafana + Loki)** (4-6h)
3. ✅ **Backups** (2h)

**Resultat:** Sira ist **9/10** - Production-ready & smart!

### **Später (1-2 Wochen):**
4. ✅ **Morgen-Briefing** (3-4h)
5. ✅ **Multi-Step Workflows** (6-8h)

**Resultat:** Sira ist **10/10** - High-End AI Assistant!

---

## ✅ **Zusammenfassung:**

### **Was Sira BEREITS hat:**
- ✅ Voice Interface (Realtime API)
- ✅ 16 Tools (Gmail, Calendar, News, Weather, etc.)
- ✅ Memory System (Qdrant + Redis)
- ✅ Fakt-Speicherung
- ✅ Error-Handling
- ✅ Basic Intent Recognition (Email)

### **Was Sira BRAUCHT für High-End:**
- 🔧 **LLM-basierte Intent-Erkennung** (WICHTIG!)
- 🔧 **Monitoring & Logging** (WICHTIG!)
- 🔧 **Backups** (WICHTIG!)
- 🔧 **Multi-Step Workflows** (Nice-to-have)
- 🔧 **Proaktives Briefing** (Nice-to-have)

**Aktuell: 7.5/10**  
**Mit Phase 1: 9/10**  
**Mit Phase 1+2: 10/10**

---

**Soll ich mit Phase 1 (LLM Intent + Monitoring + Backups) starten?**
