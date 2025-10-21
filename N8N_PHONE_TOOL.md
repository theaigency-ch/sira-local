# 📞 n8n Phone Tool - Anleitung

**Wie du das phone.call Tool in n8n hinzufügst**

---

## 🎯 **Was das Tool macht:**

```
Input: {"tool": "phone.call", "contact": "Simon", "message": "Meeting verlegt"}
  ↓
1. Findet Telefonnummer von Simon (via contacts.find)
2. Ruft Twilio API auf
3. Anruf wird getätigt
  ↓
Output: {"ok": true, "sid": "CA...", "status": "queued"}
```

---

## 🔧 **Implementierung in n8n:**

### **Option 1: Direkt in Sira (EINFACHER - BEREITS IMPLEMENTIERT!)**

**Das phone.call Tool ist BEREITS im Dockerfile implementiert!**

```javascript
// Endpoint: /sira/phone/call
// Macht automatisch:
// 1. Contact Lookup
// 2. Twilio Call
// 3. Response
```

**Du musst NICHTS in n8n ändern!**

Das Tool funktioniert über:
- `/sira/input` → leitet zu `/sira/phone/call` weiter
- Oder direkt: `/sira/phone/call`

---

### **Option 2: Als separates n8n Tool (OPTIONAL)**

**Falls du es trotzdem in n8n haben willst:**

#### **Schritt 1: Validate Input erweitern**

```javascript
// In "Validate Input" Node:
const validTools = [
  'gmail.send', 'gmail.reply', 'gmail.get',
  'calendar.free_slots', 'calendar.create', 'calendar.update', 'calendar.list',
  'contacts.find', 'contacts.upsert',
  'web.search', 'web.fetch', 'perplexity.search',
  'news.get', 'weather.get',
  'notes.log', 'reminder.set',
  'phone.call'  // ← NEU!
];
```

#### **Schritt 2: Switch Node erweitern**

```
1. Öffne "Route" (Switch) Node
2. Add Routing Rule
3. Condition: tool = "phone.call"
4. Output Name: "phone.call"
```

#### **Schritt 3: HTTP Request Node erstellen**

```
Name: "Phone Call"
Method: POST
URL: https://sira.theaigency.ch/sira/phone/call
Headers:
  - x-sira-token: {{ $env.SIRA_TOKEN }}
  - Content-Type: application/json
Body:
  {
    "contact": "={{ $json.contact }}",
    "message": "={{ $json.message }}"
  }
```

#### **Schritt 4: Response Node**

```
Name: "Respond Phone"
Response Code: 200
Body:
  {
    "ok": true,
    "sid": "={{ $json.sid }}",
    "status": "={{ $json.status }}"
  }
```

#### **Schritt 5: Verbinden**

```
Route → phone.call → Phone Call → Respond Phone
```

---

## ✅ **EMPFEHLUNG: Option 1 (bereits fertig!)**

**Warum:**
- ✅ Bereits implementiert
- ✅ Kein n8n Update nötig
- ✅ Funktioniert sofort
- ✅ Weniger Komplexität

**Das Tool funktioniert über:**
```javascript
// Via Realtime Function Call:
{
  "tool": "phone.call",
  "contact": "Simon",
  "message": "Meeting verlegt"
}

// Wird automatisch zu:
POST /sira/input
→ Sira erkennt phone.call
→ Leitet zu /sira/phone/call
→ Macht Contact Lookup
→ Ruft Twilio API
→ Fertig!
```

---

## 🧪 **Testing:**

### **Test 1: Via API**
```bash
curl -X POST https://sira.theaigency.ch/sira/input \
  -H "Content-Type: application/json" \
  -H "x-sira-token: not-required-for-rork-ai" \
  -d '{
    "tool": "phone.call",
    "contact": "+41XXXXXXXXX",
    "message": "Hallo, hier ist Sira. Test-Anruf."
  }'
```

### **Test 2: Via Voice**
```
Sage: "Ruf meine Nummer an und sage Hallo"
→ Sira erkennt phone_call Function
→ Ruft an
→ Fertig!
```

---

## 📊 **Status:**

- [x] Dockerfile Code implementiert
- [x] HTTP Endpoints erstellt
- [x] Function Call Support
- [x] Contact Lookup
- [ ] n8n Tool (optional, nicht nötig!)

---

## 💡 **Zusammenfassung:**

**Du musst NICHTS in n8n ändern!**

Das phone.call Tool ist bereits fertig und funktioniert über:
1. Realtime Function Calling
2. `/sira/input` Endpoint
3. Automatischer Contact Lookup
4. Twilio API Call

**Einfach deployen und testen!** 🚀

---

**Bereit zum Testen sobald ENV Variablen gesetzt sind!**
