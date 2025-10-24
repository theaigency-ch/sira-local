"""Notes routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import get_notes_service
from app.schemas.common import ToolExecutionResponse
from app.schemas.notes_schema import NoteLogRequest
from app.services.notes_service import NotesService
from app.services.tool_executor import ToolExecutionError

router = APIRouter()


@router.post("/log", response_model=ToolExecutionResponse)
async def log_note(
    request: NoteLogRequest,
    service: NotesService = Depends(get_notes_service),
) -> ToolExecutionResponse:
    try:
        data = await service.log(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)
