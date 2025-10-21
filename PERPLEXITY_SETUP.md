# Perplexity API Setup für Sira

## 🔑 API Key erstellen

### Schritt 1: Perplexity Account
1. Gehe zu: https://www.perplexity.ai/settings/api
2. Klicke "Generate API Key"
3. Kopiere den Key (beginnt mit `pplx-...`)

### Schritt 2: n8n Credential erstellen
1. Öffne n8n UI: https://n8n.theaigency.ch
2. Gehe zu: **Credentials** (linke Sidebar)
3. Klicke: **+ Add Credential**
4. Wähle: **Header Auth**
5. Konfiguriere:
   ```
   Name: Perplexity API
   Header Name: Authorization
   Header Value: Bearer pplx-DEIN_API_KEY_HIER
   ```
6. Klicke **Save**

### Schritt 3: Credential im Workflow verbinden
1. Workflow öffnen: "Sira 3.0 Tools (Final)"
2. Node öffnen: **Perplexity API**
3. Bei "Credential for Header Auth": **Perplexity API** auswählen
4. **Save** klicken

---

## 📊 Verfügbare Modelle

### 1. **sonar** (Standard)
- **Kosten:** ~$0.001 per request
- **Geschwindigkeit:** Schnell
- **Qualität:** Gut
- **Use Case:** Normale Fragen

### 2. **sonar-pro**
- **Kosten:** ~$0.005 per request
- **Geschwindigkeit:** Langsamer
- **Qualität:** Sehr gut
- **Use Case:** Komplexe Recherchen

### 3. **sonar-reasoning**
- **Kosten:** ~$0.01 per request
- **Geschwindigkeit:** Am langsamsten
- **Qualität:** Beste
- **Use Case:** Tiefe Analysen

**Empfehlung:** Start mit `sonar`, upgrade zu `sonar-pro` wenn nötig.

---

## 🧪 Test

```bash
# Test 1: Einfache Frage
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "perplexity.search",
    "query": "Was sind die neuesten KI Trends in der Schweiz 2025?",
    "model": "sonar"
  }'

# Erwartete Antwort:
{
  "ok": true,
  "answer": "Die neuesten KI Trends in der Schweiz 2025 umfassen...",
  "citations": [
    "https://example.com/article1",
    "https://example.com/article2"
  ],
  "model": "sonar"
}

# Test 2: Mit sonar-pro
curl -X POST https://n8n.theaigency.ch/webhook/sira3-tasks-create \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "perplexity.search",
    "query": "Vergleiche die KI-Regulierung in der Schweiz vs. EU",
    "model": "sonar-pro"
  }'
```

---

## 🔧 Sira Integration

### In Sira's Dockerfile erweitern:

```javascript
// Neue Intent-Erkennung für Perplexity
function shouldUsePerplexity(query) {
  const q = query.toLowerCase();
  
  // Keywords die Perplexity triggern
  const triggers = [
    'neueste', 'aktuell', 'heute', '2025', '2024',
    'was ist neu', 'trends', 'entwicklung',
    'erkläre', 'vergleiche', 'analysiere'
  ];
  
  return triggers.some(t => q.includes(t));
}

// In askText() Funktion:
if (shouldUsePerplexity(userQ)) {
  // Nutze Perplexity statt normale Antwort
  const perplexityResult = await forwardToN8N({
    tool: 'perplexity.search',
    query: userQ,
    model: 'sonar'
  });
  
  if (perplexityResult.ok) {
    return {
      ok: true,
      text: perplexityResult.answer,
      sources: perplexityResult.citations
    };
  }
}
```

---

## 📋 Wann Perplexity vs. SerpAPI?

| Frage-Typ | Tool | Beispiel |
|-----------|------|----------|
| **Erklärung** | perplexity.search | "Was ist KI?" |
| **Aktuelle News** | perplexity.search | "Neueste Entwicklungen..." |
| **Vergleich** | perplexity.search | "Schweiz vs. EU..." |
| **Analyse** | perplexity.search | "Wie funktioniert...?" |
| **Link-Suche** | web.search | "Finde Artikel über..." |
| **Spezifische URL** | web.fetch | "Lies diese Seite..." |

---

## 💰 Kosten-Schätzung

**Bei 1000 Fragen/Monat:**
- Sonar: ~$1/Monat
- Sonar Pro: ~$5/Monat
- SerpAPI: $50/Monat (5000 searches)

**Empfehlung:**
- Perplexity für intelligente Antworten
- SerpAPI für einfache Link-Suchen
- Beide kombinieren = beste Balance

---

## 🎯 Vorteile für Sira

### Vorher (nur SerpAPI):
```
User: "Was sind die neuesten KI Trends?"
Sira: [Ruft SerpAPI auf]
       [Bekommt 10 Links]
       [Muss jede Seite einzeln fetchen]
       [Zusammenfassen mit GPT]
= 11+ API Calls, langsam
```

### Nachher (mit Perplexity):
```
User: "Was sind die neuesten KI Trends?"
Sira: [Ruft Perplexity auf]
       [Bekommt direkt Antwort + Quellen]
= 1 API Call, schnell, smart!
```

---

## 🔗 Wichtige Links

- **Perplexity API Docs:** https://docs.perplexity.ai
- **API Keys:** https://www.perplexity.ai/settings/api
- **Pricing:** https://www.perplexity.ai/pricing
- **Models:** https://docs.perplexity.ai/docs/model-cards

---

## ✅ Checkliste

- [ ] Perplexity Account erstellt
- [ ] API Key generiert
- [ ] n8n Credential "Perplexity API" erstellt
- [ ] Workflow importiert
- [ ] Credential im Node verbunden
- [ ] Test durchgeführt
- [ ] Sira's Intent-Logik erweitert (optional)

---

**Erstellt:** 21.10.2025 11:21 Uhr  
**Status:** Ready to Setup  
**Kosten:** ~$1-5/Monat (je nach Nutzung)
