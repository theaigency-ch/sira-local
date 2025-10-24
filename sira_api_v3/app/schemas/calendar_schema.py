"""Schemas for calendar-related actions."""
from __future__ import annotations

from datetime import datetime
from typing import Sequence, Union

from pydantic import BaseModel, Field

DateSelector = Union[str, None]


class CalendarFreeSlotsRequest(BaseModel):
    date: DateSelector = Field(
        default=None,
        description="Date keyword (today, tomorrow, this_week) or ISO8601 date.",
    )
    duration_minutes: int = Field(default=30, ge=15, le=240)
    timezone: str | None = Field(default=None)

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {"duration_minutes": self.duration_minutes}
        if self.date:
            payload["date"] = self.date
        if self.timezone:
            payload["timezone"] = self.timezone
        return payload


class CalendarCreateRequest(BaseModel):
    summary: str = Field(max_length=200)
    start: datetime
    end: datetime
    attendees: Sequence[str] | None = None
    location: str | None = None
    description: str | None = None

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {
            "summary": self.summary,
            "start": self.start.isoformat(),
            "end": self.end.isoformat(),
        }
        if self.attendees:
            payload["attendees"] = list(self.attendees)
        if self.location:
            payload["location"] = self.location
        if self.description:
            payload["description"] = self.description
        return payload


class CalendarUpdateRequest(BaseModel):
    event_id: str = Field(alias="eventId")
    start: datetime | None = None
    end: datetime | None = None
    summary: str | None = None
    location: str | None = None
    description: str | None = None

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {"event_id": self.event_id}
        if self.start:
            payload["start"] = self.start.isoformat()
        if self.end:
            payload["end"] = self.end.isoformat()
        if self.summary:
            payload["summary"] = self.summary
        if self.location:
            payload["location"] = self.location
        if self.description:
            payload["description"] = self.description
        return payload


class CalendarListRequest(BaseModel):
    date: DateSelector | None = None
    start: datetime | None = None
    end: datetime | None = None
    limit: int = Field(default=10, ge=1, le=50)

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {"limit": self.limit}
        if self.date:
            payload["date"] = self.date
        if self.start:
            payload["start"] = self.start.isoformat()
        if self.end:
            payload["end"] = self.end.isoformat()
        return payload
