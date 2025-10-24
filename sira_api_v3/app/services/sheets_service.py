"""Google Sheets service for notes logging."""
from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from googleapiclient.discovery import build

from app.config import Settings
from app.core.google_auth import get_google_credentials
from app.schemas.notes_schema import NoteLogRequest

logger = logging.getLogger("sira_api_v3.services.sheets")


class SheetsService:
    """Direct Google Sheets API integration."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._service = None
        # TODO: Make this configurable via env var
        self._spreadsheet_id = "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms"  # Example

    def _get_service(self):
        """Lazy-load Sheets API service."""
        if not self._service:
            creds = get_google_credentials(self._settings)
            self._service = build("sheets", "v4", credentials=creds)
        return self._service

    async def log_note(self, request: NoteLogRequest) -> dict[str, Any]:
        """Log note to Google Sheet."""
        service = self._get_service()

        timestamp = request.timestamp or datetime.now()
        tags = ", ".join(request.tags) if request.tags else ""

        values = [[timestamp.isoformat(), request.title, request.content, tags]]

        body = {"values": values}

        result = (
            service.spreadsheets()
            .values()
            .append(
                spreadsheetId=self._spreadsheet_id,
                range="Sheet1!A:D",
                valueInputOption="RAW",
                body=body,
            )
            .execute()
        )

        logger.info("Note logged to sheet", extra={"updates": result.get("updates")})
        return {"ok": True, "updates": result.get("updates", {})}
