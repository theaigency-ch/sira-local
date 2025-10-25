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
    # Use configured redirect URI if available, otherwise generate from request
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
    logger.info("Starting Google OAuth2 flow", extra={"redirect_uri": redirect_uri})
    return RedirectResponse(authorization_url)


@router.get("/google/callback")
async def google_auth_callback(
    request: Request,
    code: str = None,
    state: str = None,
    error: str = None,
    settings: Settings = Depends(get_settings),
) -> HTMLResponse:
    """Handle Google OAuth2 callback."""
    # Log what we received
    logger.info("OAuth callback received", extra={
        "code": code[:20] + "..." if code else None,
        "state": state,
        "error": error,
        "full_url": str(request.url)
    })
    
    if error:
        raise HTTPException(status_code=400, detail=f"OAuth2 error: {error}")
    
    if not code:
        raise HTTPException(status_code=400, detail="OAuth2 failed: (missing_code) Missing code parameter in response.")
    
    # Use configured redirect URI if available, otherwise generate from request
    if settings.oauth_redirect_uri:
        redirect_uri = settings.oauth_redirect_uri
    else:
        redirect_uri = str(request.url_for("google_auth_callback"))
    
    flow = get_oauth_flow(settings, redirect_uri)

    try:
        # Use the full URL with query parameters
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
