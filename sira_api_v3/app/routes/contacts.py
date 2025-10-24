"""Contacts-related routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import get_contacts_service
from app.schemas.common import ToolExecutionResponse
from app.schemas.contacts_schema import ContactFindRequest, ContactUpsertRequest
from app.services.contacts_service import ContactsService
from app.services.tool_executor import ToolExecutionError

router = APIRouter()


@router.post("/find", response_model=ToolExecutionResponse)
async def find_contact(
    request: ContactFindRequest,
    service: ContactsService = Depends(get_contacts_service),
) -> ToolExecutionResponse:
    try:
        data = await service.find_contact(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)


@router.post("/upsert", response_model=ToolExecutionResponse)
async def upsert_contact(
    request: ContactUpsertRequest,
    service: ContactsService = Depends(get_contacts_service),
) -> ToolExecutionResponse:
    try:
        data = await service.upsert_contact(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)
