"""OAuth2 authentication routes."""
from __future__ import annotations

import logging
import os

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.config import Settings, get_settings
from app.core.google_auth import get_oauth_flow, save_credentials

# Allow insecure transport for localhost development
os.environ["OAUTHLIB_INSECURE_TRANSPORT"] = "1"

logger = logging.getLogger("sira_api_v3.routes.auth")

router = APIRouter()


@router.get("/google")
async def google_auth_start(
    request: Request,
    settings: Settings = Depends(get_settings),
) -> RedirectResponse:
    """Start Google OAuth2 flow."""
    redirect_uri = str(request.url_for("google_auth_callback"))
    flow = get_oauth_flow(settings, redirect_uri)
    authorization_url, state = flow.authorization_url(
        access_type="offline",
        include_granted_scopes="true",
        prompt="consent",
    )
    logger.info("Starting Google OAuth2 flow", extra={"redirect_uri": redirect_uri})
    return RedirectResponse(authorization_url)


@router.get("/google/callback")
async def google_auth_callback(
    request: Request,
    settings: Settings = Depends(get_settings),
) -> HTMLResponse:
    """Handle Google OAuth2 callback."""
    redirect_uri = str(request.url_for("google_auth_callback"))
    flow = get_oauth_flow(settings, redirect_uri)

    try:
        flow.fetch_token(authorization_response=str(request.url))
        credentials = flow.credentials
        save_credentials(credentials)
        logger.info("Google OAuth2 completed successfully")
        return HTMLResponse(
            """
            <html>
                <body style="font-family: sans-serif; padding: 40px; text-align: center;">
                    <h1 style="color: #4CAF50;">✅ Authorization Successful!</h1>
                    <p>Google APIs are now connected.</p>
                    <p>You can close this window and return to the application.</p>
                </body>
            </html>
            """
        )
    except Exception as e:
        logger.exception("Google OAuth2 failed")
        raise HTTPException(status_code=400, detail=f"OAuth2 failed: {str(e)}") from e
