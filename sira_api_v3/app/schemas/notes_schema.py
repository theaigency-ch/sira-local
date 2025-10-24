"""Schemas for note logging tool."""
from __future__ import annotations

from datetime import datetime
from typing import Sequence

from pydantic import BaseModel, Field


class NoteLogRequest(BaseModel):
    title: str = Field(max_length=200)
    content: str
    tags: Sequence[str] | None = None
    timestamp: datetime | None = None

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {
            "title": self.title,
            "content": self.content,
        }
        if self.tags:
            payload["tags"] = list(self.tags)
        if self.timestamp:
            payload["timestamp"] = self.timestamp.isoformat()
        return payload
