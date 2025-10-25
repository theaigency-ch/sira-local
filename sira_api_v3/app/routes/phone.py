"""Phone/Twilio routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Form
from fastapi.responses import Response

from app.dependencies import get_phone_service
from app.schemas.common import ToolExecutionResponse
from app.schemas.phone_schema import PhoneCallRequest, PhoneStatusResponse
from app.services.phone_service import PhoneService

router = APIRouter()


@router.post("/call", response_model=ToolExecutionResponse)
async def make_call(
    request: PhoneCallRequest,
    service: PhoneService = Depends(get_phone_service),
) -> ToolExecutionResponse:
    """Initiate an outgoing phone call with TTS message."""
    try:
        data = await service.make_call(request)
    except (RuntimeError, ValueError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    if not data.get("ok"):
        raise HTTPException(status_code=500, detail=data.get("error", "Call failed"))

    return ToolExecutionResponse(ok=True, data=data)


@router.get("/status", response_model=PhoneStatusResponse)
async def get_status(
    service: PhoneService = Depends(get_phone_service),
) -> PhoneStatusResponse:
    """Get phone service configuration status."""
    status = service.get_status()
    return PhoneStatusResponse(**status)


@router.post("/incoming")
async def incoming_call(
    From: str = Form(...),
    To: str = Form(...),
    CallSid: str = Form(...),
    CallStatus: str = Form(None),
) -> Response:
    """Handle incoming Twilio call webhook."""
    # Log the incoming call
    import logging
    logger = logging.getLogger("sira_api_v3.routes.phone")
    logger.info(
        "Incoming call",
        extra={
            "from": From,
            "to": To,
            "call_sid": CallSid,
            "status": CallStatus,
        },
    )
    
    # Return TwiML response
    twiml = """<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say language="de-DE">Hallo, hier ist Sira. Ich bin momentan nicht verfügbar. Bitte hinterlassen Sie eine Nachricht nach dem Signalton.</Say>
    <Record maxLength="120" transcribe="false" playBeep="true"/>
    <Say language="de-DE">Vielen Dank für Ihre Nachricht. Auf Wiederhören.</Say>
</Response>"""
    
    return Response(content=twiml, media_type="application/xml")
