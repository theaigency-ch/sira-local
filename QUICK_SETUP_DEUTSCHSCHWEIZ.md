# 🇨🇭 Quick Setup: Sales AI Agent für Deutschschweiz

## 15-Minuten-Setup für Deutschschweizer Dienstleister

---

## ✅ Voraussetzungen

Bevor Sie starten, stellen Sie sicher, dass Sie haben:

- [ ] **Google-Account** (Gmail, Google Sheets, Google Docs)
- [ ] **OpenAI-Account** (ChatGPT API) → [platform.openai.com](https://platform.openai.com)
- [ ] **HubSpot-Account** (kostenlos) → [hubspot.com](https://hubspot.com)
- [ ] **N8N-Account** (kostenlos) → [n8n.io](https://n8n.io)
- [ ] **Apify-Account** (optional) → [apify.com](https://apify.com)
- [ ] **Slack-Workspace** (optional)

**Geschätzte Zeit:** 15-20 Minuten

---

## 📋 Schritt 1: Google Sheet vorbereiten (3 Min)

### **1.1 Neues Google Sheet erstellen**

1. Gehe zu [sheets.google.com](https://sheets.google.com)
2. Erstelle ein neues Sheet: "Sales Agent Leads"
3. Erstelle 3 Tabs:
   - **Leads** (Haupt-Tab)
   - **Weekly Reports** (für Reports)
   - **Config** (für Einstellungen)

### **1.2 "Leads" Tab konfigurieren**

Füge folgende Spalten hinzu (Zeile 1):

```
email | first_name | last_name | title | organization_name | organization_website_url | organization_location | industry | num_of_employees | phone | linkedin_url | organization_linkedin_url | discovered_at | spam_check_passed | intent_signals | personal_research | lead_score | lead_tier | scoring_reasoning | recommended_approach | enriched_at | status | email_subject | email_body | linkedin_message | personalization_hook | value_metric | draft_created_at | sent_at | reply_at | reply_sentiment | meeting_booked_at | meeting_scheduled_for
```

**Tipp:** Kopiere diese Zeile und füge sie in Zeile 1 ein.

### **1.3 Sheet-ID kopieren**

1. Kopiere die Sheet-ID aus der URL:
   ```
   https://docs.google.com/spreadsheets/d/[DIESE_ID_KOPIEREN]/edit
   ```
2. Speichere sie für später: `YOUR_SHEET_ID`

---

## 🔑 Schritt 2: API-Keys besorgen (5 Min)

### **2.1 OpenAI API Key**

1. Gehe zu [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Klicke "Create new secret key"
3. Kopiere den Key: `sk-...`
4. Speichere ihn sicher

**Kosten:** ~CHF 30-40/Monat bei 500 Leads

### **2.2 HubSpot API Key**

1. Gehe zu HubSpot → Settings → Integrations → API Key
2. Klicke "Generate API Key"
3. Kopiere den Key
4. Speichere ihn sicher

**Kosten:** CHF 0 (Free Plan ausreichend)

### **2.3 Apify API Key (optional)**

1. Gehe zu [apify.com/account/api](https://apify.com/account/api)
2. Kopiere deinen API Token
3. Speichere ihn sicher

**Kosten:** ~CHF 50/Monat bei 500 Leads

**Alternative:** LinkedIn Sales Navigator Export nutzen

### **2.4 Slack Webhook (optional)**

1. Gehe zu [api.slack.com/apps](https://api.slack.com/apps)
2. Erstelle eine neue App
3. Aktiviere "Incoming Webhooks"
4. Erstelle einen Webhook für deinen Channel
5. Kopiere die Webhook-URL

**Kosten:** CHF 0

---

## 🛠️ Schritt 3: N8N Workflows importieren (5 Min)

### **3.1 N8N Account erstellen**

1. Gehe zu [n8n.io](https://n8n.io)
2. Erstelle einen Account (kostenlos)
3. Öffne dein N8N Dashboard

### **3.2 Workflows importieren**

Importiere folgende 6 Workflows:

1. **workflow-1-discovery-intent.json** → Lead-Findung & Enrichment
2. **workflow-2-multichannel-outreach.json** → E-Mail-Generierung
3. **workflow-2b-send-approved.json** → E-Mail-Versand
4. **workflow-3-reply-intelligence.json** → Antwort-Analyse
5. **workflow-4-meeting-recycling.json** → Meeting-Automation
6. **workflow-5-analytics-digest.json** → Wöchentliche Reports

**So importierst du:**
1. N8N → Workflows → "Import from File"
2. Wähle die JSON-Datei
3. Klicke "Import"
4. Wiederhole für alle 6 Workflows

---

## ⚙️ Schritt 4: Workflows konfigurieren (5 Min)

### **4.1 Workflow 1: Discovery + Intent Signals**

Öffne den Workflow und passe den **"⚙️ Config & ICP"** Node an:

```javascript
// FÜR MAKLER IN ZÜRICH:
target_position: "Geschäftsführer, Inhaber, Partner, Makler"
target_location: "Zürich, Basel, Bern, Luzern, Zug, St. Gallen"
target_industry: "Real Estate, Immobilien, Property Management"
company_size: "1-50"
max_leads: 25

// API Keys:
apify_api_key: "YOUR_APIFY_KEY"
google_sheet_id: "YOUR_SHEET_ID"
hubspot_api_key: "YOUR_HUBSPOT_KEY"
slack_webhook: "YOUR_SLACK_WEBHOOK"
```

**Andere Branchen:**
- **Anwälte:** `target_position: "Rechtsanwalt, Partner, Fachanwalt"`, `target_industry: "Legal Services, Law Firm"`
- **Treuhänder:** `target_position: "Treuhänder, Steuerberater"`, `target_industry: "Accounting, Tax Advisory"`
- **Personalbüros:** `target_position: "Geschäftsführer, HR Manager"`, `target_industry: "Recruiting, HR Services"`

Siehe `ICP_DEUTSCHSCHWEIZ.md` für alle Branchen.

### **4.2 Workflow 2: Multi-Channel Outreach**

Passe den **"⚙️ Outreach Config"** Node an:

```javascript
google_sheet_id: "YOUR_SHEET_ID"
service_doc_id: "YOUR_GOOGLE_DOC_ID" // Siehe Schritt 5
brand_name: "Ihre Firma"
booking_link: "https://calendly.com/your-link"
hubspot_api_key: "YOUR_HUBSPOT_KEY"
```

### **4.3 Workflow 2B: Send Approved**

Passe den **"⚙️ Send Config"** Node an:

```javascript
google_sheet_id: "YOUR_SHEET_ID"
hubspot_api_key: "YOUR_HUBSPOT_KEY"
daily_send_limit: 50 // Max E-Mails pro Tag
```

### **4.4 Workflows 3-5**

Passe jeweils die Config-Nodes an mit:
- `google_sheet_id`
- `hubspot_api_key`
- `slack_webhook` (optional)

---

## 📄 Schritt 5: Service-Dokumentation erstellen (2 Min)

### **5.1 Google Doc erstellen**

1. Gehe zu [docs.google.com](https://docs.google.com)
2. Erstelle ein neues Doc: "Sales Agent Services"
3. Beschreibe deine Dienstleistungen:

**Beispiel für Makler:**
```
# Unsere Dienstleistungen

## Lead-Generierung für Immobilienmakler

Wir helfen Maklern in der Deutschschweiz, ihre Lead-Generierung zu automatisieren.

**Was wir bieten:**
- 15-20 qualifizierte Kaufinteressenten pro Monat
- Automatische Lead-Qualifizierung nach Budget & Präferenzen
- CHF 50'000-100'000 zusätzliches Transaktionsvolumen

**Wie es funktioniert:**
1. KI findet potenzielle Käufer in Ihrer Region
2. Automatische Qualifizierung nach Ihren Kriterien
3. Personalisierte Ansprache
4. Übergabe qualifizierter Leads an Sie

**Preise:**
- Setup: CHF 3'000 einmalig
- Monatlich: CHF 500
- Performance-basiert: 5% vom generierten Volumen

**Erfolgsgeschichte:**
Ein Makler in Basel generiert seit 3 Monaten konstant CHF 50'000 zusätzliches Volumen.
```

4. Kopiere die Doc-ID aus der URL:
   ```
   https://docs.google.com/document/d/[DIESE_ID_KOPIEREN]/edit
   ```
5. Füge die ID in Workflow 2 ein

---

## 🎯 Schritt 6: ICP definieren (bereits erledigt!)

Die ICP-Konfiguration ist bereits in den Workflows für Deutschschweiz optimiert:

✅ **Sprache:** Deutsch (Grüezi, Sie)
✅ **Region:** Nur Deutschschweiz (Zürich, Basel, Bern, etc.)
✅ **Ton:** Konservativ, professionell
✅ **Zahlen:** CHF, Schweizer Format (1'000)
✅ **Datenschutz:** DSG-konform

**Anpassungen pro Branche:** Siehe `ICP_DEUTSCHSCHWEIZ.md`

---

## 🚀 Schritt 7: Test-Run (5 Min)

### **7.1 Workflow 1 testen**

1. Öffne Workflow 1: "Discovery + Intent Signals"
2. Klicke "Execute Workflow"
3. Warte 2-3 Minuten
4. Prüfe dein Google Sheet → Tab "Leads"
5. Du solltest 25 neue Leads sehen mit:
   - ✅ E-Mail-Adressen
   - ✅ Lead Score (0-100)
   - ✅ Lead Tier (Hot/Warm/Cold)
   - ✅ Intent Signals
   - ✅ Status: "Enriched"

**Probleme?**
- Keine Leads? → Prüfe Apify API Key
- Fehler? → Prüfe Google Sheet ID
- Keine Scores? → Prüfe OpenAI API Key

### **7.2 Workflow 2 testen**

1. Öffne Workflow 2: "Multi-Channel Outreach"
2. Klicke "Execute Workflow"
3. Warte 1-2 Minuten
4. Prüfe dein Google Sheet → Tab "Leads"
5. Du solltest sehen:
   - ✅ E-Mail Subject
   - ✅ E-Mail Body (auf Deutsch mit "Grüezi")
   - ✅ LinkedIn Message
   - ✅ Status: "Draft Ready"

**Prüfe die E-Mail-Qualität:**
- ✅ Beginnt mit "Grüezi Herr/Frau [Name]"?
- ✅ Verwendet "Sie" (nicht "Du")?
- ✅ CHF-Zahlen im Schweizer Format (1'000)?
- ✅ Professioneller, konservativer Ton?
- ✅ Spezifische Details erwähnt?

### **7.3 Manuelle Freigabe**

1. Gehe zu Google Sheet → Tab "Leads"
2. Wähle die besten 5-10 Leads
3. Ändere Status von "Draft Ready" zu **"Approved"**
4. Speichere

### **7.4 Workflow 2B testen**

1. Öffne Workflow 2B: "Send Approved"
2. Klicke "Execute Workflow"
3. Die E-Mails werden versendet!
4. Prüfe dein Gmail → "Gesendet"
5. Prüfe Google Sheet → Status: "Sent"

**Gratulation! Deine ersten E-Mails sind raus! 🎉**

---

## 📅 Schritt 8: Automatisierung aktivieren

### **8.1 Schedules aktivieren**

Aktiviere die automatischen Schedules:

**Workflow 1:** Täglich 9:00 Uhr (Lead-Findung)
**Workflow 2B:** Täglich 14:00 Uhr (E-Mail-Versand)
**Workflow 3:** Täglich 10:00 Uhr (Reply-Check)
**Workflow 4:** Alle 6 Stunden (Meeting-Check)
**Workflow 5:** Montags 8:00 Uhr (Wöchentlicher Report)

**So aktivierst du:**
1. Öffne jeden Workflow
2. Klicke auf den Schedule-Trigger-Node
3. Aktiviere "Active"
4. Speichere

### **8.2 Monitoring einrichten**

**Täglich checken:**
- Google Sheet → Neue Leads?
- Gmail → Antworten?
- Slack → Hot Lead Alerts?

**Wöchentlich checken:**
- Workflow 5 Report → Performance?
- Google Sheet → Status-Verteilung?

---

## ✅ Checkliste: Setup abgeschlossen?

- [ ] Google Sheet erstellt mit 3 Tabs
- [ ] Alle API Keys besorgt (OpenAI, HubSpot, Apify, Slack)
- [ ] 6 Workflows in N8N importiert
- [ ] Alle Config-Nodes angepasst (ICP für Deutschschweiz)
- [ ] Service-Dokumentation erstellt (Google Doc)
- [ ] Workflow 1 getestet → 25 Leads gefunden
- [ ] Workflow 2 getestet → E-Mails generiert (auf Deutsch)
- [ ] Workflow 2B getestet → E-Mails versendet
- [ ] Schedules aktiviert
- [ ] Monitoring eingerichtet

**Alles ✅? Herzlichen Glückwunsch! Dein Sales AI Agent läuft! 🇨🇭**

---

## 📊 Was passiert jetzt?

### **Woche 1: Lernen & Optimieren**

**Täglich:**
- 25 neue Leads (Deutschschweiz)
- 10-15 E-Mails versenden
- 2-3 Antworten erwarten

**Aufgaben:**
- E-Mail-Qualität prüfen
- Antworten manuell beantworten
- ICP anpassen wenn nötig

**Zeitaufwand:** 1-2 Stunden/Tag

### **Woche 2-3: Skalieren**

**Täglich:**
- 50 neue Leads
- 20-30 E-Mails versenden
- 4-6 Antworten erwarten
- 1-2 Meetings buchen

**Aufgaben:**
- Weniger manuelle Freigabe
- Mehr automatisieren
- Follow-ups optimieren

**Zeitaufwand:** 1 Stunde/Tag

### **Ab Woche 4: Vollautomatisch**

**Täglich:**
- 100+ neue Leads
- 50+ E-Mails versenden
- 8-12 Antworten erwarten
- 2-4 Meetings buchen

**Aufgaben:**
- Nur noch Monitoring
- Wöchentliche Reports checken
- Meetings vorbereiten

**Zeitaufwand:** 30 Minuten/Woche

---

## 🎯 Erwartete Ergebnisse (Monat 1)

### **Makler in Zürich:**
```
500 Leads gefunden
250 qualifiziert (50%)
200 E-Mails sent
30-40 Replies (15-20%)
10-16 Meetings (5-8%)
2-3 Deals (50% Close Rate)

Umsatz: CHF 30'000-45'000
Kosten: CHF 200
ROI: 14'900-22'400%
```

### **Treuhänder in Zug:**
```
500 Leads gefunden
250 qualifiziert (50%)
200 E-Mails sent
24-36 Replies (12-18%)
10-14 Meetings (5-7%)
3-4 Deals (50% Close Rate)

Umsatz: CHF 15'000-20'000
Kosten: CHF 150
ROI: 9'900-13'233%
```

---

## 💡 Tipps für maximalen Erfolg

### **1. Qualität > Quantität**

✅ Lieber 25 perfekte Leads als 100 mittelmässige
✅ Manuelle Freigabe in Woche 1-2
✅ E-Mail-Templates optimieren

### **2. Schweizer Stil beibehalten**

✅ Immer "Grüezi" & "Sie"
✅ Konservativ, professionell
✅ Keine übertriebenen Versprechungen
✅ CHF-Zahlen, Schweizer Format

### **3. Schnell antworten**

✅ Positive Antworten innerhalb 2 Stunden beantworten
✅ Meetings sofort buchen
✅ Slack-Alerts aktivieren

### **4. Kontinuierlich optimieren**

✅ Wöchentliche Reports analysieren
✅ Best-performing E-Mails identifizieren
✅ ICP anpassen basierend auf Ergebnissen

---

## 🆘 Troubleshooting

### **Problem: Keine Leads gefunden**

**Lösung:**
- Prüfe Apify API Key
- Prüfe ICP-Konfiguration (zu spezifisch?)
- Erweitere `target_location` (mehr Kantone)

### **Problem: E-Mails nicht auf Deutsch**

**Lösung:**
- Prüfe Workflow 2 → AI-Prompt
- Sollte beginnen mit "Du bist ein Experte für professionelle Cold Emails im Schweizer B2B-Bereich"
- Sollte enthalten "Schreibe auf DEUTSCH für die DEUTSCHSCHWEIZ"

### **Problem: Niedrige Reply Rate (<10%)**

**Lösung:**
- E-Mail-Qualität prüfen (zu generisch?)
- ICP anpassen (bessere Qualifizierung)
- Personalisierung verbessern
- Schweizer Referenzen hinzufügen

### **Problem: E-Mails landen im Spam**

**Lösung:**
- Gmail Warm-up machen (langsam starten mit 5-10/Tag)
- SPF/DKIM/DMARC konfigurieren
- Opt-out-Link hinzufügen
- Weniger E-Mails pro Tag senden

---

## 📞 Support

**Brauchen Sie Hilfe?**

📧 E-Mail: support@yourcompany.com
💬 Slack: [Community beitreten]
📚 Dokumentation: 
- `ICP_DEUTSCHSCHWEIZ.md` → ICP-Konfigurationen
- `SALES_PITCH_DEUTSCHSCHWEIZ.md` → Sales-Dokumentation
- `COMPLETE_SETUP_GUIDE.md` → Detaillierte Anleitung

---

## 🎉 Nächste Schritte

1. **Jetzt:** Setup abschliessen (15 Min)
2. **Heute:** Erste Test-E-Mails versenden
3. **Diese Woche:** 50-100 Leads kontaktieren
4. **Nächste Woche:** Erste Meetings buchen
5. **Monat 1:** 2-3 Deals abschliessen

**Viel Erfolg mit Ihrem Sales AI Agent in der Deutschschweiz! 🇨🇭🚀**
