"""Calendar service with direct Google Calendar API integration."""
from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Any

from googleapiclient.discovery import build

from app.config import Settings
from app.core.google_auth import get_google_credentials
from app.schemas.calendar_schema import (
    CalendarCreateRequest,
    CalendarFreeSlotsRequest,
    CalendarListRequest,
    CalendarUpdateRequest,
)

logger = logging.getLogger("sira_api_v3.services.calendar")


class CalendarServiceImpl:
    """Direct Google Calendar API integration."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._service = None

    def _get_service(self):
        """Lazy-load Calendar API service."""
        if not self._service:
            creds = get_google_credentials(self._settings)
            self._service = build("calendar", "v3", credentials=creds)
        return self._service

    def _parse_date_selector(self, date_str: str | None) -> tuple[datetime, datetime]:
        """Parse date selector to datetime range."""
        now = datetime.now()
        if not date_str or date_str == "today":
            start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            end = start + timedelta(days=1)
        elif date_str == "tomorrow":
            start = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
            end = start + timedelta(days=1)
        elif date_str == "this_week":
            start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            end = start + timedelta(days=7)
        elif date_str == "next_week":
            start = (now + timedelta(days=7)).replace(hour=0, minute=0, second=0, microsecond=0)
            end = start + timedelta(days=7)
        else:
            # Assume ISO date
            start = datetime.fromisoformat(date_str).replace(hour=0, minute=0, second=0, microsecond=0)
            end = start + timedelta(days=1)
        return start, end

    async def find_free_slots(self, request: CalendarFreeSlotsRequest) -> dict[str, Any]:
        """Find free time slots."""
        service = self._get_service()
        start, end = self._parse_date_selector(request.date)

        body = {
            "timeMin": start.isoformat() + "Z",
            "timeMax": end.isoformat() + "Z",
            "items": [{"id": "primary"}],
        }

        result = service.freebusy().query(body=body).execute()
        busy = result["calendars"]["primary"]["busy"]

        # Simple free slot calculation
        free_slots = []
        current = start
        for busy_period in busy:
            busy_start = datetime.fromisoformat(busy_period["start"].replace("Z", ""))
            if current < busy_start:
                free_slots.append(
                    {
                        "start": current.isoformat(),
                        "end": busy_start.isoformat(),
                        "duration_minutes": int((busy_start - current).total_seconds() / 60),
                    }
                )
            current = datetime.fromisoformat(busy_period["end"].replace("Z", ""))

        if current < end:
            free_slots.append(
                {
                    "start": current.isoformat(),
                    "end": end.isoformat(),
                    "duration_minutes": int((end - current).total_seconds() / 60),
                }
            )

        logger.info("Free slots found", extra={"count": len(free_slots)})
        return {"ok": True, "slots": free_slots}

    async def create_event(self, request: CalendarCreateRequest) -> dict[str, Any]:
        """Create calendar event."""
        service = self._get_service()

        event = {
            "summary": request.summary,
            "start": {"dateTime": request.start.isoformat(), "timeZone": self._settings.default_timezone},
            "end": {"dateTime": request.end.isoformat(), "timeZone": self._settings.default_timezone},
        }

        if request.location:
            event["location"] = request.location
        if request.description:
            event["description"] = request.description
        if request.attendees:
            event["attendees"] = [{"email": email} for email in request.attendees]

        result = service.events().insert(calendarId="primary", body=event).execute()

        logger.info("Event created", extra={"event_id": result["id"]})
        return {"ok": True, "eventId": result["id"], "link": result.get("htmlLink")}

    async def update_event(self, request: CalendarUpdateRequest) -> dict[str, Any]:
        """Update calendar event."""
        service = self._get_service()

        event = service.events().get(calendarId="primary", eventId=request.event_id).execute()

        if request.summary:
            event["summary"] = request.summary
        if request.start:
            event["start"] = {"dateTime": request.start.isoformat(), "timeZone": self._settings.default_timezone}
        if request.end:
            event["end"] = {"dateTime": request.end.isoformat(), "timeZone": self._settings.default_timezone}
        if request.location:
            event["location"] = request.location
        if request.description:
            event["description"] = request.description

        result = service.events().update(calendarId="primary", eventId=request.event_id, body=event).execute()

        logger.info("Event updated", extra={"event_id": result["id"]})
        return {"ok": True, "eventId": result["id"]}

    async def list_events(self, request: CalendarListRequest) -> dict[str, Any]:
        """List calendar events."""
        service = self._get_service()

        if request.date:
            start, end = self._parse_date_selector(request.date)
        elif request.start and request.end:
            start, end = request.start, request.end
        else:
            start, end = self._parse_date_selector("today")

        # Format time for Google Calendar API (RFC3339)
        # If datetime is naive (no timezone), add Z
        # If datetime has timezone, use as-is
        time_min = start.isoformat() if start.tzinfo else start.isoformat() + "Z"
        time_max = end.isoformat() if end.tzinfo else end.isoformat() + "Z"

        result = (
            service.events()
            .list(
                calendarId="primary",
                timeMin=time_min,
                timeMax=time_max,
                maxResults=request.limit,
                singleEvents=True,
                orderBy="startTime",
            )
            .execute()
        )

        events = []
        for item in result.get("items", []):
            events.append(
                {
                    "id": item["id"],
                    "summary": item.get("summary", ""),
                    "start": item["start"].get("dateTime", item["start"].get("date")),
                    "end": item["end"].get("dateTime", item["end"].get("date")),
                    "location": item.get("location"),
                    "description": item.get("description"),
                }
            )

        logger.info("Events listed", extra={"count": len(events)})
        return {"ok": True, "count": len(events), "events": events}
