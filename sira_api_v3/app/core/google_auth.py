"""Google OAuth2 authentication and token management."""
from __future__ import annotations

import json
import logging
from typing import Any

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow

from app.config import Settings
from app.core.redis import get_sync_redis_client

logger = logging.getLogger("sira_api_v3.core.google_auth")

REDIS_TOKEN_KEY = "google:oauth_token"
SCOPES = [
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/contacts",
    "https://www.googleapis.com/auth/tasks",
    "https://www.googleapis.com/auth/spreadsheets",
]


def get_oauth_flow(settings: Settings, redirect_uri: str) -> Flow:
    """Create OAuth2 flow for Google APIs."""
    client_config = {
        "web": {
            "client_id": settings.google_client_id,
            "client_secret": settings.google_client_secret,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "redirect_uris": [redirect_uri],
        }
    }
    return Flow.from_client_config(client_config, scopes=SCOPES, redirect_uri=redirect_uri)


def save_credentials(creds: Credentials) -> None:
    """Save credentials to Redis."""
    redis_client = get_sync_redis_client()
    token_data = {
        "token": creds.token,
        "refresh_token": creds.refresh_token,
        "token_uri": creds.token_uri,
        "client_id": creds.client_id,
        "client_secret": creds.client_secret,
        "scopes": creds.scopes,
    }
    redis_client.set(REDIS_TOKEN_KEY, json.dumps(token_data))
    logger.info("Google credentials saved to Redis", extra={"key": REDIS_TOKEN_KEY})


def load_credentials() -> Credentials | None:
    """Load credentials from Redis."""
    redis_client = get_sync_redis_client()
    token_json = redis_client.get(REDIS_TOKEN_KEY)
    
    if not token_json:
        logger.warning("No Google token found in Redis", extra={"key": REDIS_TOKEN_KEY})
        return None

    token_data = json.loads(token_json)

    creds = Credentials(
        token=token_data.get("token"),
        refresh_token=token_data.get("refresh_token"),
        token_uri=token_data.get("token_uri"),
        client_id=token_data.get("client_id"),
        client_secret=token_data.get("client_secret"),
        scopes=token_data.get("scopes"),
    )

    # Refresh if expired
    if creds.expired and creds.refresh_token:
        logger.info("Refreshing expired Google token")
        creds.refresh(Request())
        save_credentials(creds)

    return creds


def get_google_credentials(settings: Settings) -> Credentials:
    """Get valid Google credentials, raising if not available."""
    creds = load_credentials()
    if not creds:
        raise RuntimeError(
            "Google OAuth2 not configured. Please visit /auth/google to authorize."
        )
    return creds
