"""Schemas for weather tool requests."""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class WeatherGetRequest(BaseModel):
    location: str = Field(max_length=120)
    units: Literal["metric", "imperial"] | None = None
    days: int = Field(default=1, ge=1, le=7)

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {"location": self.location, "days": self.days}
        if self.units:
            payload["units"] = self.units
        return payload
