"""Calendar service with direct Google Calendar API integration."""
from __future__ import annotations

from app.services.calendar_service_impl import CalendarServiceImpl


class CalendarService(CalendarServiceImpl):
    """Calendar related operations mapping to Google Calendar tools."""

    pass
