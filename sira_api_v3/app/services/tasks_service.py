"""Google Tasks service for reminders."""
from __future__ import annotations

import logging
from typing import Any

from googleapiclient.discovery import build

from app.config import Settings
from app.core.google_auth import get_google_credentials
from app.schemas.reminder_schema import ReminderSetRequest

logger = logging.getLogger("sira_api_v3.services.tasks")


class TasksService:
    """Direct Google Tasks API integration."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._service = None

    def _get_service(self):
        """Lazy-load Tasks API service."""
        if not self._service:
            creds = get_google_credentials(self._settings)
            self._service = build("tasks", "v1", credentials=creds)
        return self._service

    async def set_reminder(self, request: ReminderSetRequest) -> dict[str, Any]:
        """Create task/reminder."""
        service = self._get_service()

        # Get default task list
        task_lists = service.tasklists().list().execute()
        task_list_id = task_lists["items"][0]["id"]

        task = {
            "title": request.title,
            "due": request.due.isoformat() + "Z",
        }

        if request.notes:
            task["notes"] = request.notes

        result = service.tasks().insert(tasklist=task_list_id, body=task).execute()

        logger.info("Task created", extra={"task_id": result["id"]})
        return {"ok": True, "id": result["id"], "title": result["title"], "due": result.get("due")}
