# Service Account Setup (KEIN OAuth2 nötig!)

## 1. Google Cloud Console
1. Gehe zu https://console.cloud.google.com
2. Wähle Projekt: fundamental-rig-460021-p2
3. IAM & Admin → Service Accounts
4. CREATE SERVICE ACCOUNT
5. Name: sira-api-service
6. CREATE AND CONTINUE
7. Role: "Gmail API Admin" oder "Project Editor"
8. DONE

## 2. Schlüssel erstellen
1. Klicke auf den Service Account
2. KEYS → ADD KEY → Create new key
3. JSON auswählen
4. DOWNLOAD

## 3. In FastAPI nutzen
```python
import json
from google.oauth2 import service_account

# Lade Credentials
credentials = service_account.Credentials.from_service_account_info(
    json.loads(GOOGLE_SERVICE_ACCOUNT_JSON),
    scopes=['https://www.googleapis.com/auth/gmail.modify']
)

# Nutze direkt ohne OAuth2!
service = build('gmail', 'v1', credentials=credentials)
```

## 4. Environment Variable setzen
In Coolify:
- GOOGLE_SERVICE_ACCOUNT_JSON = (Inhalt der JSON Datei)

FERTIG! Kein OAuth2 Flow nötig!
