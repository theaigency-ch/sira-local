# 🔐 OAuth2 Setup - Komplette Anleitung

**Sira API v3 - Google OAuth2 Konfiguration**

---

## ✅ Status: ERFOLGREICH KONFIGURIERT

OAuth2 funktioniert vollständig mit Gmail, Calendar und Contacts APIs.

---

## 📋 Voraussetzungen

1. **Google Cloud Project** erstellt
2. **APIs aktiviert:**
   - Gmail API
   - Google Calendar API
   - Google People API (Contacts)
3. **OAuth 2.0 Client erstellt**
4. **Ngrok Account** (kostenlos)

---

## 🚀 Schritt-für-Schritt Anleitung

### **1. Google Cloud Console Setup**

#### **1.1 Projekt erstellen/auswählen:**
```
https://console.cloud.google.com
→ Projekt: fundamental-rig-460021-p2
```

#### **1.2 APIs aktivieren:**
```
APIs & Services → Library → Suche nach:
- Gmail API → Enable
- Google Calendar API → Enable
- Google People API → Enable
```

#### **1.3 OAuth Consent Screen konfigurieren:**
```
APIs & Services → OAuth consent screen
- User Type: External
- App name: Sira n8n
- User support email: theaigency.ch@gmail.com
- Developer contact: theaigency.ch@gmail.com
- Scopes hinzufügen:
  ✅ .../auth/gmail.modify
  ✅ .../auth/calendar
  ✅ .../auth/contacts
```

#### **1.4 OAuth 2.0 Client erstellen:**
```
APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client ID
- Application type: Web application
- Name: Google Drive API
- Authorized JavaScript origins:
  - https://n8n.theaigency.ch
  - http://localhost:5678
  - http://localhost:8791
  - https://sira.theaigency.ch
  
- Authorized redirect URIs:
  - https://nonradioactive-margrett-supersolar.ngrok-free.dev/auth/google/callback
  - https://n8n.theaigency.ch/rest/oauth2-credential/callback
  - http://localhost:5678/rest/oauth2-credential/callback
```

**Wichtig:** Client-ID und Client-Secret kopieren!

---

### **2. Ngrok Setup**

#### **2.1 Ngrok Account erstellen:**
```
https://ngrok.com/signup
→ Kostenlos registrieren
```

#### **2.2 Authtoken kopieren:**
```
https://dashboard.ngrok.com/get-started/your-authtoken
→ Token kopieren
```

#### **2.3 Ngrok auf VPS installieren:**
```bash
# SSH auf VPS
ssh root@31.97.79.208

# Ngrok installieren
wget -q -O - https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
  tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo 'deb https://ngrok-agent.s3.amazonaws.com buster main' | \
  tee /etc/apt/sources.list.d/ngrok.list
apt update
apt install ngrok -y

# Authtoken konfigurieren
ngrok config add-authtoken DEIN_TOKEN_HIER
```

#### **2.4 Ngrok starten:**
```bash
# Ngrok im Hintergrund starten
nohup ngrok http 8792 --log=stdout > /tmp/ngrok.log 2>&1 &

# URL abrufen (nach 5 Sekunden)
sleep 5
curl -s http://localhost:4040/api/tunnels | \
  python3 -c 'import sys,json; data=json.load(sys.stdin); print(data["tunnels"][0]["public_url"])'
```

**Beispiel-URL:** `https://nonradioactive-margrett-supersolar.ngrok-free.dev`

---

### **3. Coolify Environment Variables**

#### **3.1 In Coolify konfigurieren:**
```
Coolify → Applications → theaigency-ch/sira-local → Environment Variables
```

#### **3.2 Variablen hinzufügen:**
```bash
GOOGLE_CLIENT_ID=[DEINE_CLIENT_ID]
GOOGLE_CLIENT_SECRET=[DEIN_CLIENT_SECRET]
GOOGLE_PROJECT_ID=[DEIN_PROJECT_ID]
OAUTH_REDIRECT_URI=https://[DEINE_NGROK_URL]/auth/google/callback
```

#### **3.3 Redeploy:**
```
Coolify → Redeploy Button klicken
```

---

### **4. Google Cloud Console - Redirect URI aktualisieren**

#### **4.1 Redirect URI hinzufügen:**
```
Google Cloud Console → APIs & Services → Credentials
→ OAuth 2.0 Client "Google Drive API" anklicken
→ Authorized redirect URIs → + ADD URI
→ https://nonradioactive-margrett-supersolar.ngrok-free.dev/auth/google/callback
→ SAVE
```

**Wichtig:** Die ngrok URL ändert sich bei jedem Neustart! Dann muss die Redirect URI aktualisiert werden.

---

### **5. OAuth2 Flow testen**

#### **5.1 Browser öffnen:**
```
https://nonradioactive-margrett-supersolar.ngrok-free.dev/auth/google
```

#### **5.2 Google Login:**
- Google Account auswählen
- Berechtigungen akzeptieren
- Erfolgsmeldung: "Authorization Successful!"

#### **5.3 Tokens prüfen:**
```bash
# SSH auf VPS
ssh root@31.97.79.208

# Redis prüfen
docker exec redis-sira-hcs08c84g0o0sc8wwkg4ssk4 \
  redis-cli -a DohajERz0wlqQiIqzrMuJtVlKxxlSQA71aYYHeU1t2w \
  KEYS 'google:*'
```

**Erwartete Ausgabe:** `google:credentials` (oder ähnlich)

---

## 🔧 Troubleshooting

### **Problem: "redirect_uri_mismatch"**
**Lösung:** 
1. Prüfe ob die ngrok URL in Google Cloud Console eingetragen ist
2. Prüfe ob `OAUTH_REDIRECT_URI` in Coolify gesetzt ist
3. Redeploy FastAPI

### **Problem: "invalid_client"**
**Lösung:**
1. Prüfe `GOOGLE_CLIENT_ID` und `GOOGLE_CLIENT_SECRET`
2. Stelle sicher, dass der richtige OAuth Client verwendet wird

### **Problem: Ngrok URL ändert sich**
**Lösung:**
1. **Kostenlos:** Jedes Mal manuell in Google Cloud Console aktualisieren
2. **Paid ($8/Monat):** Feste ngrok Domain (z.B. `sira-api.ngrok.io`)

### **Problem: "missing_code"**
**Lösung:**
1. Prüfe ob der Code die Query-Parameter korrekt verarbeitet
2. Prüfe Logs: `docker logs ss4wkgsckcog480o8oosw8wk-155152508965`

---

## 📊 Code-Referenz

### **FastAPI OAuth2 Route:**
```python
@router.get("/google")
async def google_auth_start(
    request: Request,
    settings: Settings = Depends(get_settings),
) -> RedirectResponse:
    """Start Google OAuth2 flow."""
    # Use configured redirect URI if available
    if settings.oauth_redirect_uri:
        redirect_uri = settings.oauth_redirect_uri
    else:
        redirect_uri = str(request.url_for("google_auth_callback"))
    
    flow = get_oauth_flow(settings, redirect_uri)
    authorization_url, state = flow.authorization_url(
        access_type="offline",
        include_granted_scopes="true",
        prompt="consent",
    )
    return RedirectResponse(authorization_url)
```

### **Config:**
```python
class Settings(BaseSettings):
    google_client_id: str | None = Field(default=None, alias="GOOGLE_CLIENT_ID")
    google_client_secret: str | None = Field(default=None, alias="GOOGLE_CLIENT_SECRET")
    google_project_id: str | None = Field(default=None, alias="GOOGLE_PROJECT_ID")
    oauth_redirect_uri: str | None = Field(default=None, alias="OAUTH_REDIRECT_URI")
```

---

## 🎯 Alternative: Permanente Domain

### **Option 1: Ngrok Paid Plan ($8/Monat)**
```bash
# Feste Domain reservieren
ngrok http 8792 --domain=sira-api.ngrok.io
```

**Vorteil:** URL ändert sich nie mehr!

### **Option 2: Traefik-Routing fixen**
```bash
# api.sira.theaigency.ch zum Laufen bringen
# Traefik-Labels in Coolify korrekt setzen
```

**Vorteil:** Eigene Domain, kein Ngrok nötig

---

## ✅ Checkliste

- [x] Google Cloud Project erstellt
- [x] APIs aktiviert (Gmail, Calendar, Contacts)
- [x] OAuth 2.0 Client erstellt
- [x] Ngrok installiert und konfiguriert
- [x] Ngrok läuft im Hintergrund
- [x] Environment Variables in Coolify gesetzt
- [x] Redirect URI in Google Cloud Console eingetragen
- [x] OAuth2 Flow erfolgreich getestet
- [x] Tokens in Redis gespeichert

---

**Status:** ✅ PRODUKTIV
**Letzter Test:** 25. Oktober 2025, 17:54 Uhr
**Ergebnis:** Authorization Successful!
