"""Schemas for Twilio phone integration."""
from __future__ import annotations

from pydantic import BaseModel, Field


class PhoneCallRequest(BaseModel):
    """Request to make an outgoing phone call via Twilio."""

    contact: str = Field(
        max_length=200,
        description="Contact name or phone number (e.g., 'Peter' or '+41625391299')",
    )
    message: str = Field(
        max_length=500,
        description="Message to speak via TTS",
    )

    def to_payload(self) -> dict[str, object]:
        return {
            "contact": self.contact,
            "message": self.message,
        }


class PhoneStatusResponse(BaseModel):
    """Response for phone status endpoint."""

    enabled: bool
    number: str | None = None
    configured: bool
