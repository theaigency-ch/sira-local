"""Twilio phone service for outgoing calls."""
from __future__ import annotations

import logging
from typing import Any

from twilio.rest import Client

from app.config import Settings
from app.schemas.phone_schema import PhoneCallRequest

logger = logging.getLogger("sira_api_v3.services.phone")


class PhoneService:
    """Service for Twilio phone operations."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client: Client | None = None
        if settings.twilio_account_sid and settings.twilio_auth_token:
            self._client = Client(settings.twilio_account_sid, settings.twilio_auth_token)

    async def make_call(self, request: PhoneCallRequest) -> dict[str, Any]:
        """Make an outgoing call with TTS message."""
        if not self._client:
            raise RuntimeError("Twilio not configured (missing SID or Auth Token)")

        if not self._settings.twilio_phone_number:
            raise RuntimeError("Twilio phone number not configured")

        # Simple phone number validation/formatting
        to_number = request.contact
        if not to_number.startswith("+"):
            # Assume it's a contact name - in production, lookup via contacts.find
            raise ValueError(f"Contact lookup not implemented; provide full number like +41625391299")

        # Create TwiML for TTS
        twiml = f'<Response><Say voice="Polly.Vicki" language="de-DE">{request.message}</Say></Response>'

        try:
            call = self._client.calls.create(
                to=to_number,
                from_=self._settings.twilio_phone_number,
                twiml=twiml,
            )
            logger.info("Call initiated", extra={"call_sid": call.sid, "to": to_number})
            return {
                "ok": True,
                "sid": call.sid,
                "status": call.status,
                "to": to_number,
            }
        except Exception as e:
            logger.exception("Twilio call failed", extra={"to": to_number})
            return {
                "ok": False,
                "error": str(e),
            }

    def get_status(self) -> dict[str, Any]:
        """Return phone service status."""
        return {
            "enabled": self._settings.sira_phone_enabled,
            "number": self._settings.twilio_phone_number,
            "configured": self._client is not None,
        }
