"""Route registration for sira_api_v3."""
from __future__ import annotations

from fastapi import APIRouter, FastAPI

from . import auth, calendar, contacts, email, news, notes, phone, reminder, search, weather, webhook

API_PREFIX = "/api/v1"


def register_routes(app: FastAPI) -> None:
    # Webhook route (n8n-compatible, no prefix)
    app.include_router(webhook.router, prefix="/webhook", tags=["webhook"])
    
    # Auth routes (no prefix, outside /api/v1)
    app.include_router(auth.router, prefix="/auth", tags=["auth"])

    api_router = APIRouter(prefix=API_PREFIX)

    api_router.include_router(email.router, prefix="/email", tags=["email"])
    api_router.include_router(calendar.router, prefix="/calendar", tags=["calendar"])
    api_router.include_router(contacts.router, prefix="/contacts", tags=["contacts"])
    api_router.include_router(search.router, prefix="/search", tags=["search"])
    api_router.include_router(news.router, prefix="/news", tags=["news"])
    api_router.include_router(weather.router, prefix="/weather", tags=["weather"])
    api_router.include_router(notes.router, prefix="/notes", tags=["notes"])
    api_router.include_router(reminder.router, prefix="/reminder", tags=["reminder"])
    api_router.include_router(phone.router, prefix="/phone", tags=["phone"])

    app.include_router(api_router)
