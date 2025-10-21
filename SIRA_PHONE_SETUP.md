# 📞 Sira Telefon-Integration Setup

**Status:** In Entwicklung  
**Datum:** 21.10.2025

---

## 🎯 **Was Sira können wird:**

### **Ausgehende Anrufe:**
- "Ruf Simon an und sage ihm X"
- Sira ruft Kontakt an
- Führt Gespräch
- Loggt alles

### **Eingehende Anrufe:**
- Jemand ruft Sira's Nummer an
- Sira antwortet wie eine echte Assistentin
- Vereinbart Termine
- Nimmt Nachrichten entgegen
- Leitet weiter wenn nötig

---

## 📋 **Setup-Anleitung:**

### **1. Twilio Account erstellen**

```
1. Gehe zu: https://www.twilio.com/try-twilio
2. Sign Up (kostenlos starten)
3. Verifiziere Email + Telefonnummer
4. Du bekommst $15 Trial Credit
```

### **2. Schweizer Telefonnummer kaufen**

```
1. In Twilio Console: Phone Numbers → Buy a Number
2. Wähle Country: Switzerland (+41)
3. Capabilities: Voice ✅ (SMS optional)
4. Suche verfügbare Nummern
5. Kaufe Nummer (~CHF 1/Monat)
```

**Deine Sira Nummer:** `+41 XX XXX XX XX`

### **3. API Credentials holen**

```
1. Twilio Console → Account → API keys & tokens
2. Kopiere:
   - Account SID: ACxxxxxxxxxxxxxxxxx
   - Auth Token: xxxxxxxxxxxxxxxxx
3. Speichere sicher!
```

### **4. TwiML Bin erstellen (für Incoming Calls)**

```
1. Twilio Console → TwiML Bins → Create new
2. Name: "Sira Incoming Handler"
3. TwiML Code:
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="Polly.Vicki" language="de-DE">
        Guten Tag, hier ist Sira, die Assistentin von Peter Baka. 
        Einen Moment bitte, ich verbinde Sie.
    </Say>
    <Dial>
        <Stream url="wss://sira.theaigency.ch/sira/phone/stream" />
    </Dial>
</Response>
```

```
4. Save
5. Kopiere TwiML Bin URL
```

### **5. Nummer konfigurieren**

```
1. Phone Numbers → Manage → Active numbers
2. Klicke auf deine +41 Nummer
3. Voice Configuration:
   - A CALL COMES IN: TwiML Bin
   - Wähle: "Sira Incoming Handler"
4. Save
```

---

## 🔑 **Environment Variables**

**In Coolify ENV hinzufügen:**

```bash
# Twilio Credentials
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxx
TWILIO_PHONE_NUMBER=+41XXXXXXXXX

# Sira Phone Config
SIRA_PHONE_ENABLED=true
SIRA_PHONE_OWNER_NAME="Peter Baka"
SIRA_PHONE_OWNER_PHONE=+41XXXXXXXXX  # Deine private Nummer
SIRA_PHONE_FORWARD_URGENT=true
```

---

## 🧪 **Testing:**

### **Test 1: Eingehender Anruf**
```
1. Rufe Sira's Nummer an: +41 XX XXX XX XX
2. Sira sollte antworten: "Guten Tag, hier ist Sira..."
3. Sage etwas
4. Prüfe Logs in Coolify
```

### **Test 2: Ausgehender Anruf**
```
1. Via Voice UI: "Ruf meine Nummer an"
2. Dein Telefon sollte klingeln
3. Sira spricht mit dir
```

### **Test 3: Termin vereinbaren**
```
1. Rufe Sira an
2. Sage: "Ich möchte einen Termin vereinbaren"
3. Sira prüft Kalender
4. Sira schlägt Zeit vor
5. Termin wird erstellt
```

---

## 📊 **Kosten-Übersicht:**

```
Twilio Nummer: CHF 1/Monat
Eingehende Anrufe: CHF 0.01/Minute
Ausgehende Anrufe: CHF 0.013/Minute
OpenAI Realtime: CHF 0.06/Minute

Beispiel (50 Anrufe/Monat à 3 Min):
= 50 × 3 × 0.07 = CHF 10.50/Monat

Trial Credit: $15 (reicht für ~200 Minuten)
```

---

## 🎯 **Use Cases:**

### **Business:**
- Termin-Vereinbarung
- Lead Qualification
- Support Hotline
- Nachricht entgegennehmen

### **Persönlich:**
- "Ruf Restaurant an und reserviere Tisch"
- "Ruf Zahnarzt an und verschiebe Termin"
- "Nimm Anrufe entgegen wenn ich beschäftigt bin"

---

## 🚀 **Nächste Schritte:**

1. ✅ Twilio Account erstellen
2. ✅ Nummer kaufen
3. ✅ Credentials in Coolify ENV
4. ⏳ Code-Implementierung (in Arbeit)
5. ⏳ Testing
6. ⏳ Go Live!

---

## 📞 **Support:**

Bei Fragen:
- Twilio Docs: https://www.twilio.com/docs/voice
- OpenAI Realtime: https://platform.openai.com/docs/guides/realtime

---

**Status:** Setup-Guide fertig ✅  
**Nächster Schritt:** Code-Implementierung
