# 📞 Sira Telefon-Integration - Implementierung

**Datum:** 21.10.2025  
**Status:** Ready to implement

---

## 🏗️ **Architektur:**

```
┌─────────────────────────────────────────────┐
│           Telefon-Integration               │
├─────────────────────────────────────────────┤
│                                             │
│  Ausgehende Anrufe:                         │
│  User → Sira Voice → Function Call          │
│    → n8n (phone.call)                       │
│    → Twilio API                             │
│    → OpenAI Realtime Bridge                 │
│    → Anruf wird getätigt                    │
│                                             │
│  Eingehende Anrufe:                         │
│  Anrufer → Twilio Nummer                    │
│    → Webhook → Sira                         │
│    → OpenAI Realtime Session                │
│    → Bidirektionale Konversation            │
│    → Tools (calendar, notes, etc.)          │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 📝 **Implementierungs-Schritte:**

### **1. Dockerfile Erweiterungen**

**Neue Funktionen hinzufügen:**

```javascript
/* ---------------------- Twilio Integration ---------------------- */
const TWILIO_SID = process.env.TWILIO_ACCOUNT_SID || '';
const TWILIO_TOKEN = process.env.TWILIO_AUTH_TOKEN || '';
const TWILIO_PHONE = process.env.TWILIO_PHONE_NUMBER || '';
const PHONE_ENABLED = process.env.SIRA_PHONE_ENABLED === 'true';

// Twilio Client initialisieren
async function twilioCall(to, message){
  if(!TWILIO_SID || !TWILIO_TOKEN) return {ok:false, error:'Twilio not configured'};
  
  const auth = Buffer.from(TWILIO_SID + ':' + TWILIO_TOKEN).toString('base64');
  
  try{
    const r = await withTimeout(`https://api.twilio.com/2010-04-01/Accounts/${TWILIO_SID}/Calls.json`,{
      method:'POST',
      headers:{
        'Authorization': 'Basic ' + auth,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        To: to,
        From: TWILIO_PHONE,
        Twiml: `<Response><Say voice="Polly.Vicki" language="de-DE">${message}</Say></Response>`
      })
    },10000);
    
    const result = await r.json();
    return {ok: r.ok, sid: result.sid, status: result.status};
  }catch(e){
    return {ok:false, error: e.message};
  }
}

// Eingehende Anrufe Handler
async function handleIncomingCall(req){
  const from = req.body.From;
  const to = req.body.To;
  const callSid = req.body.CallSid;
  
  console.log('[Phone] Eingehender Anruf von:', from);
  
  // Lookup Kontakt
  let callerName = 'Unbekannt';
  try{
    const contact = await forwardToN8N({tool: 'contacts.find', query: from});
    if(contact.ok && contact.results && contact.results.length > 0){
      callerName = contact.results[0].name;
    }
  }catch{}
  
  // Erstelle Realtime Session mit Phone Instructions
  const rtSession = await createPhoneRealtimeSession(callerName, from);
  
  // TwiML Response mit Stream
  const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="Polly.Vicki" language="de-DE">
        Guten Tag, hier ist Sira, die Assistentin von Peter Baka.
    </Say>
    <Connect>
        <Stream url="${rtSession.streamUrl}">
            <Parameter name="callSid" value="${callSid}" />
            <Parameter name="from" value="${from}" />
            <Parameter name="callerName" value="${callerName}" />
        </Stream>
    </Connect>
</Response>`;
  
  return twiml;
}

// Realtime Session für Telefonie
async function createPhoneRealtimeSession(callerName, callerNumber){
  const profile = await loadProfile();
  const shortMem = memTail(8000);
  
  const phoneInstructions = `
Du bist Sira, die persönliche Assistentin von ${profile.name || 'Peter Baka'}.

AKTUELLER ANRUF:
- Anrufer: ${callerName}
- Nummer: ${callerNumber}

DEINE AUFGABEN:
1. Freundlich und professionell sein
2. Fragen worum es geht
3. Je nach Anliegen:
   - Termin vereinbaren (calendar_create)
   - Nachricht entgegennehmen (notes_log)
   - Informationen geben
   - An ${profile.name} weiterleiten (wenn dringend)

VERFÜGBARE FUNCTIONS:
- calendar_create: Termin erstellen
- calendar_list: Termine prüfen
- notes_log: Nachricht speichern
- gmail_send: Email senden

KONTEXT:
${shortMem}

Sei kurz und präzise - das ist ein Telefongespräch!
`;

  // Erstelle Realtime Session
  const r = await withTimeout(BASE+'/v1/realtime/sessions',{
    method:'POST',
    headers:{
      Authorization:'Bearer '+KEY,
      'content-type':'application/json',
      'OpenAI-Beta':'realtime=v1'
    },
    body: JSON.stringify({
      model: MODEL_RT,
      voice: VOICE_RT,
      modalities:['audio','text'],
      instructions: phoneInstructions,
      tools: [
        {
          type: 'function',
          name: 'calendar_create',
          description: 'Erstellt einen Termin',
          parameters: {
            type: 'object',
            properties: {
              summary: {type: 'string'},
              start: {type: 'string'},
              end: {type: 'string'}
            },
            required: ['summary', 'start', 'end']
          }
        },
        {
          type: 'function',
          name: 'notes_log',
          description: 'Speichert eine Nachricht',
          parameters: {
            type: 'object',
            properties: {
              note: {type: 'string'},
              category: {type: 'string'}
            },
            required: ['note']
          }
        }
      ]
    })
  },10000);
  
  const session = await r.json();
  return {
    streamUrl: `wss://sira.theaigency.ch/sira/phone/stream/${session.id}`,
    sessionId: session.id
  };
}
```

### **2. Neue Endpoints**

```javascript
// Eingehende Anrufe
if (req.method==='POST' && p==='/sira/phone/incoming'){
  const twiml = await handleIncomingCall(req);
  res.setHeader('content-type', 'text/xml');
  return res.end(twiml);
}

// WebSocket Stream für Twilio
if (req.method==='GET' && p.startsWith('/sira/phone/stream/')){
  // WebSocket Upgrade für Twilio Stream
  // Verbindet Twilio Audio <-> OpenAI Realtime
  // (Komplexer - braucht WebSocket Server)
}

// Ausgehende Anrufe (via n8n)
if (req.method==='POST' && p==='/sira/phone/call'){
  if(!checkToken(req,res)) return;
  const body = await readBody(req);
  const to = body.to;
  const message = body.message;
  
  const result = await twilioCall(to, message);
  noStore(res,'application/json');
  return res.end(JSON.stringify(result));
}

// Phone Status
if (req.method==='GET' && p==='/sira/phone/status'){
  noStore(res,'application/json');
  return res.end(JSON.stringify({
    enabled: PHONE_ENABLED,
    number: TWILIO_PHONE,
    configured: !!(TWILIO_SID && TWILIO_TOKEN)
  }));
}
```

### **3. Realtime Function für phone.call**

```javascript
// In createRealtimeEphemeral tools array ergänzen:
{
  type: 'function',
  name: 'phone_call',
  description: 'Ruft eine Telefonnummer an',
  parameters: {
    type: 'object',
    properties: {
      contact: {
        type: 'string',
        description: 'Name oder Telefonnummer'
      },
      message: {
        type: 'string',
        description: 'Was soll Sira sagen?'
      }
    },
    required: ['contact', 'message']
  }
}
```

---

## 🧪 **Testing-Szenarien:**

### **Test 1: Einfacher ausgehender Anruf**
```bash
curl -X POST https://sira.theaigency.ch/sira/phone/call \
  -H "Content-Type: application/json" \
  -H "x-sira-token: YOUR_TOKEN" \
  -d '{
    "to": "+41XXXXXXXXX",
    "message": "Hallo, hier ist Sira. Dies ist ein Test-Anruf."
  }'
```

### **Test 2: Via Voice**
```
User: "Ruf meine Nummer an"
→ Sira erkennt phone_call Function
→ Findet deine Nummer im Profil
→ Ruft an
```

### **Test 3: Eingehender Anruf**
```
1. Rufe Twilio Nummer an
2. Sira antwortet
3. Sage: "Ich möchte einen Termin"
4. Sira prüft Kalender
5. Sira schlägt Zeit vor
```

---

## 📊 **Implementierungs-Status:**

- [x] Setup-Guide erstellt
- [x] Architektur definiert
- [ ] Dockerfile Code hinzufügen
- [ ] n8n Tool erstellen
- [ ] WebSocket Bridge implementieren
- [ ] Testing
- [ ] Dokumentation

---

## ⚠️ **Wichtige Hinweise:**

### **WebSocket Komplexität:**
Die Twilio Stream <-> OpenAI Realtime Bridge ist komplex:
- Braucht WebSocket Server
- Audio-Format Konvertierung (μ-law <-> PCM)
- Bidirektionale Streaming

**Lösung:** 
- Phase 1: Einfache TTS Anrufe (funktioniert sofort)
- Phase 2: Realtime Bridge (braucht mehr Zeit)

### **Latenz:**
- TTS Anrufe: ~1-2 Sekunden Verzögerung (ok)
- Realtime: ~500ms (besser, aber komplexer)

---

## 🚀 **Nächste Schritte:**

1. **DU:** Twilio Account erstellen + Nummer kaufen
2. **ICH:** Code implementieren (Phase 1 - TTS)
3. **WIR:** Testen
4. **ICH:** Phase 2 (Realtime) wenn Phase 1 funktioniert

---

**Bereit für die Implementierung!** 🎯
