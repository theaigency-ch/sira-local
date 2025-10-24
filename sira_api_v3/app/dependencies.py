"""Shared dependency utilities for FastAPI routes."""
from __future__ import annotations

from fastapi import Request

from app.config import Settings, get_settings
from app.core.qdrant import get_qdrant_client
from app.core.redis import get_redis_client
from app.services.calendar_service import CalendarService
from app.services.contacts_service import ContactsService
from app.services.email_service import EmailService
from app.services.news_service import NewsService
from app.services.notes_service import NotesService
from app.services.reminder_service import ReminderService
from app.services.search_service import PerplexityService, WebFetchService, WebSearchService
from app.services.phone_service import PhoneService
from app.services.weather_service import WeatherService


def provide_settings() -> Settings:
    """Dependency wrapper for application settings."""

    return get_settings()


async def get_redis(request: Request):
    """Return Redis client attached to the application state."""

    return get_redis_client(request.app.state)


async def get_qdrant(request: Request):
    """Return Qdrant client attached to the application state."""

    return get_qdrant_client(request.app.state)


def get_email_service() -> EmailService:
    return EmailService(get_settings())


def get_calendar_service() -> CalendarService:
    return CalendarService(get_settings())


def get_contacts_service() -> ContactsService:
    return ContactsService(get_settings())


def get_web_search_service() -> WebSearchService:
    return WebSearchService(get_settings())


def get_web_fetch_service() -> WebFetchService:
    return WebFetchService(get_settings())


def get_perplexity_service() -> PerplexityService:
    return PerplexityService(get_settings())


def get_news_service() -> NewsService:
    return NewsService(get_settings())


def get_weather_service() -> WeatherService:
    return WeatherService(get_settings())


def get_notes_service() -> NotesService:
    return NotesService(get_settings())


def get_reminder_service() -> ReminderService:
    return ReminderService(get_settings())


def get_phone_service() -> PhoneService:
    return PhoneService(get_settings())
