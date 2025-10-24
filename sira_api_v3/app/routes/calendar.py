"""Calendar-related API routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import get_calendar_service
from app.schemas.calendar_schema import (
    CalendarCreateRequest,
    CalendarFreeSlotsRequest,
    CalendarListRequest,
    CalendarUpdateRequest,
)
from app.schemas.common import ToolExecutionResponse
from app.services.calendar_service import CalendarService
from app.services.tool_executor import ToolExecutionError

router = APIRouter()


@router.post("/free-slots", response_model=ToolExecutionResponse)
async def find_free_slots(
    request: CalendarFreeSlotsRequest,
    service: CalendarService = Depends(get_calendar_service),
) -> ToolExecutionResponse:
    try:
        data = await service.find_free_slots(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)


@router.post("/create", response_model=ToolExecutionResponse)
async def create_event(
    request: CalendarCreateRequest,
    service: CalendarService = Depends(get_calendar_service),
) -> ToolExecutionResponse:
    try:
        data = await service.create_event(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)


@router.post("/update", response_model=ToolExecutionResponse)
async def update_event(
    request: CalendarUpdateRequest,
    service: CalendarService = Depends(get_calendar_service),
) -> ToolExecutionResponse:
    try:
        data = await service.update_event(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)


@router.post("/list", response_model=ToolExecutionResponse)
async def list_events(
    request: CalendarListRequest,
    service: CalendarService = Depends(get_calendar_service),
) -> ToolExecutionResponse:
    try:
        data = await service.list_events(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)
