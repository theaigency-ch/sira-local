"""Email-related API routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies import get_email_service
from app.schemas.common import ToolExecutionResponse
from app.schemas.email_schema import EmailGetRequest, EmailReplyRequest, EmailSendRequest
from app.services.email_service import EmailService

router = APIRouter()


@router.post("/send", response_model=ToolExecutionResponse, status_code=status.HTTP_200_OK)
async def send_email(
    request: EmailSendRequest,
    service: EmailService = Depends(get_email_service),
) -> ToolExecutionResponse:
    try:
        data = await service.send_email(request)
    except Exception as exc:  # pragma: no cover - raised from external service
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)


@router.post("/reply", response_model=ToolExecutionResponse)
async def reply_email(
    request: EmailReplyRequest,
    service: EmailService = Depends(get_email_service),
) -> ToolExecutionResponse:
    try:
        data = await service.reply_email(request)
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)


@router.post("/list", response_model=ToolExecutionResponse)
async def list_emails(
    request: EmailGetRequest,
    service: EmailService = Depends(get_email_service),
) -> ToolExecutionResponse:
    try:
        data = await service.list_emails(request)
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)
