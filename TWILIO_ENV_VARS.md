# 🔑 Twilio Environment Variables

**Für Coolify Deployment**

---

## 📋 **Neue ENV Variablen hinzufügen:**

```bash
# Twilio Credentials
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_PHONE_NUMBER=+41XXXXXXXXX

# Sira Phone Configuration
SIRA_PHONE_ENABLED=true
SIRA_PHONE_OWNER_NAME=Peter Baka
```

**WICHTIG:** Ersetze die X mit deinen echten Credentials aus Twilio!

---

## ✅ **In Coolify einfügen:**

```
1. Coolify → SiraNet-2.0 → Environment Variables
2. Füge die obigen Variablen hinzu
3. Save
4. Redeploy
```

---

## 🧪 **Testing nach Deployment:**

### **Test 1: Phone Status prüfen**
```bash
curl https://sira.theaigency.ch/sira/phone/status
```

**Erwartete Response:**
```json
{
  "enabled": true,
  "number": "+41625391972",
  "configured": true
}
```

### **Test 2: Einfacher Anruf (TTS)**
```bash
curl -X POST https://sira.theaigency.ch/sira/phone/call \
  -H "Content-Type: application/json" \
  -H "x-sira-token: not-required-for-rork-ai" \
  -d '{
    "to": "+41XXXXXXXXX",
    "message": "Hallo, hier ist Sira. Dies ist ein Test-Anruf."
  }'
```

### **Test 3: Via Voice UI**
```
1. Gehe zu: https://sira.theaigency.ch/sira/rt/v2/ptt
2. Sage: "Ruf meine Nummer an und sage Hallo"
3. Dein Telefon sollte klingeln!
```

---

## 📞 **Was jetzt funktioniert:**

✅ **Ausgehende Anrufe:**
- Via API: `/sira/phone/call`
- Via Voice: "Ruf [Kontakt] an"
- Via n8n: Tool `phone.call`

✅ **Features:**
- Kontakt-Lookup (Name → Telefonnummer)
- TTS (Text-to-Speech)
- Twilio Integration
- Function Calling Support

---

## 🚧 **Was noch NICHT funktioniert:**

⏳ **Eingehende Anrufe:**
- Braucht Twilio Webhook Configuration
- Kommt in Phase 2

⏳ **Realtime Bidirektional:**
- Braucht WebSocket Bridge
- Kommt in Phase 2

---

## 🎯 **Nächste Schritte:**

1. ✅ ENV Variablen in Coolify einfügen
2. ✅ Redeploy
3. ✅ Testen
4. ⏳ Phase 2: Eingehende Anrufe

---

**Status:** Ready to deploy! 🚀
