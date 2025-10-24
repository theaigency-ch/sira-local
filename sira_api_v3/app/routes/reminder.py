"""Reminder routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import get_reminder_service
from app.schemas.common import ToolExecutionResponse
from app.schemas.reminder_schema import ReminderSetRequest
from app.services.reminder_service import ReminderService
from app.services.tool_executor import ToolExecutionError

router = APIRouter()


@router.post("/set", response_model=ToolExecutionResponse)
async def set_reminder(
    request: ReminderSetRequest,
    service: ReminderService = Depends(get_reminder_service),
) -> ToolExecutionResponse:
    try:
        data = await service.set_reminder(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)
