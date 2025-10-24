"""Schemas for reminder tool."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class ReminderSetRequest(BaseModel):
    title: str = Field(max_length=200)
    due: datetime = Field(alias="date")
    notes: str | None = None

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {
            "title": self.title,
            "due": self.due.isoformat(),
        }
        if self.notes:
            payload["notes"] = self.notes
        return payload
