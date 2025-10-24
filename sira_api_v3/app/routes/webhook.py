"""Webhook endpoint for n8n-compatible tool execution."""
from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request

from app.config import Settings, get_settings
from app.dependencies import (
    get_calendar_service,
    get_contacts_service,
    get_email_service,
    get_notes_service,
    get_phone_service,
    get_reminder_service,
    get_web_fetch_service,
    get_web_search_service,
)
from app.services.calendar_service import CalendarService
from app.services.contacts_service import ContactsService
from app.services.email_service import EmailService
from app.services.notes_service import NotesService
from app.services.phone_service import PhoneService
from app.services.reminder_service import ReminderService
from app.services.search_service import WebFetchService, WebSearchService

logger = logging.getLogger("sira_api_v3.routes.webhook")

router = APIRouter()


@router.post("/sira3-tasks-create")
async def webhook_handler(
    request: Request,
    settings: Settings = Depends(get_settings),
    email_service: EmailService = Depends(get_email_service),
    calendar_service: CalendarService = Depends(get_calendar_service),
    contacts_service: ContactsService = Depends(get_contacts_service),
    web_search_service: WebSearchService = Depends(get_web_search_service),
    web_fetch_service: WebFetchService = Depends(get_web_fetch_service),
    notes_service: NotesService = Depends(get_notes_service),
    reminder_service: ReminderService = Depends(get_reminder_service),
    phone_service: PhoneService = Depends(get_phone_service),
) -> dict[str, Any]:
    """
    n8n-compatible webhook endpoint.
    
    Receives: {"tool": "gmail.send", "to": "...", "subject": "...", ...}
    Returns: {"ok": true, "data": {...}}
    """
    try:
        body = await request.json()
    except Exception as e:
        logger.error("Failed to parse JSON body", extra={"error": str(e)})
        raise HTTPException(status_code=400, detail="Invalid JSON") from e

    tool = body.get("tool")
    if not tool:
        raise HTTPException(status_code=400, detail="Missing 'tool' parameter")

    logger.info("Webhook request", extra={"tool": tool})

    try:
        # Gmail Tools
        if tool == "gmail.send":
            from app.schemas.email_schema import EmailRecipient, EmailSendRequest
            
            recipients = [EmailRecipient(email=r["email"], name=r.get("name")) for r in body.get("to", [])]
            request_obj = EmailSendRequest(
                to=recipients,
                subject=body.get("subject", ""),
                body=body.get("body", ""),
                cc=[EmailRecipient(email=r["email"], name=r.get("name")) for r in body.get("cc", [])] if body.get("cc") else None,
                bcc=[EmailRecipient(email=r["email"], name=r.get("name")) for r in body.get("bcc", [])] if body.get("bcc") else None,
                reply_to=body.get("reply_to"),
            )
            data = await email_service.send_email(request_obj)
            return {"ok": True, "data": data}

        elif tool == "gmail.reply":
            from app.schemas.email_schema import EmailReplyRequest
            
            request_obj = EmailReplyRequest(
                thread_id=body.get("thread_id", ""),
                message_id=body.get("message_id", ""),
                body=body.get("body", ""),
            )
            data = await email_service.reply_email(request_obj)
            return {"ok": True, "data": data}

        elif tool == "gmail.get":
            from app.schemas.email_schema import EmailGetRequest
            
            request_obj = EmailGetRequest(
                filter=body.get("filter"),
                limit=body.get("limit", 5),
                label_ids=body.get("label_ids"),
            )
            data = await email_service.list_emails(request_obj)
            return {"ok": True, "data": data}

        # Calendar Tools
        elif tool == "calendar.free_slots":
            from app.schemas.calendar_schema import CalendarFreeSlotsRequest
            
            request_obj = CalendarFreeSlotsRequest(
                date=body.get("date"),
                duration_minutes=body.get("duration_minutes", 60),
            )
            data = await calendar_service.find_free_slots(request_obj)
            return {"ok": True, "data": data}

        elif tool == "calendar.create":
            from datetime import datetime
            from app.schemas.calendar_schema import CalendarCreateRequest
            
            request_obj = CalendarCreateRequest(
                summary=body.get("summary", ""),
                start=datetime.fromisoformat(body.get("start", "")),
                end=datetime.fromisoformat(body.get("end", "")),
                location=body.get("location"),
                description=body.get("description"),
                attendees=body.get("attendees"),
            )
            data = await calendar_service.create_event(request_obj)
            return {"ok": True, "data": data}

        elif tool == "calendar.update":
            from datetime import datetime
            from app.schemas.calendar_schema import CalendarUpdateRequest
            
            request_obj = CalendarUpdateRequest(
                event_id=body.get("event_id", ""),
                summary=body.get("summary"),
                start=datetime.fromisoformat(body["start"]) if body.get("start") else None,
                end=datetime.fromisoformat(body["end"]) if body.get("end") else None,
                location=body.get("location"),
                description=body.get("description"),
            )
            data = await calendar_service.update_event(request_obj)
            return {"ok": True, "data": data}

        elif tool == "calendar.list":
            from datetime import datetime
            from app.schemas.calendar_schema import CalendarListRequest
            
            request_obj = CalendarListRequest(
                date=body.get("date"),
                start=datetime.fromisoformat(body["start"]) if body.get("start") else None,
                end=datetime.fromisoformat(body["end"]) if body.get("end") else None,
                limit=body.get("limit", 10),
            )
            data = await calendar_service.list_events(request_obj)
            return {"ok": True, "data": data}

        # Contacts Tools
        elif tool == "contacts.find":
            from app.schemas.contacts_schema import ContactFindRequest
            
            request_obj = ContactFindRequest(
                query=body.get("query", ""),
                limit=body.get("limit", 10),
            )
            data = await contacts_service.find_contact(request_obj)
            return {"ok": True, "data": data}

        elif tool == "contacts.upsert":
            from app.schemas.contacts_schema import ContactUpsertRequest
            
            request_obj = ContactUpsertRequest(
                email=body.get("email", ""),
                first_name=body.get("first_name"),
                last_name=body.get("last_name"),
                phone=body.get("phone"),
                company=body.get("company"),
            )
            data = await contacts_service.upsert_contact(request_obj)
            return {"ok": True, "data": data}

        # Web Tools
        elif tool == "web.search":
            from app.schemas.search_schema import WebSearchRequest
            
            request_obj = WebSearchRequest(
                query=body.get("query", ""),
                num_results=body.get("num_results", 5),
                location=body.get("location"),
                language=body.get("language"),
                safe=body.get("safe", True),
            )
            data = await web_search_service.search(request_obj)
            return {"ok": True, "data": data}

        elif tool == "web.fetch":
            from pydantic import HttpUrl
            from app.schemas.search_schema import WebFetchRequest
            
            request_obj = WebFetchRequest(
                url=HttpUrl(body.get("url", "")),
            )
            data = await web_fetch_service.fetch(request_obj)
            return {"ok": True, "data": data}

        # Notes Tool
        elif tool == "notes.log":
            from datetime import datetime
            from app.schemas.notes_schema import NoteLogRequest
            
            request_obj = NoteLogRequest(
                title=body.get("title", ""),
                content=body.get("content", ""),
                tags=body.get("tags"),
                timestamp=datetime.fromisoformat(body["timestamp"]) if body.get("timestamp") else None,
            )
            data = await notes_service.log(request_obj)
            return {"ok": True, "data": data}

        # Reminder Tool
        elif tool == "reminder.set":
            from datetime import datetime
            from app.schemas.reminder_schema import ReminderSetRequest
            
            request_obj = ReminderSetRequest(
                title=body.get("title", ""),
                due=datetime.fromisoformat(body.get("due", "")),
                notes=body.get("notes"),
            )
            data = await reminder_service.set_reminder(request_obj)
            return {"ok": True, "data": data}

        # Phone Tool
        elif tool == "phone.call":
            from app.schemas.phone_schema import PhoneCallRequest
            
            request_obj = PhoneCallRequest(
                contact=body.get("contact", ""),
                message=body.get("message", ""),
            )
            data = await phone_service.make_call(request_obj)
            return {"ok": True, "data": data}

        # News & Weather (stub - to be implemented)
        elif tool == "news.get":
            return {"ok": False, "error": "news.get not yet implemented"}

        elif tool == "weather.get":
            return {"ok": False, "error": "weather.get not yet implemented"}

        elif tool == "perplexity.search":
            return {"ok": False, "error": "perplexity.search not yet implemented"}

        else:
            raise HTTPException(status_code=400, detail=f"Unknown tool: {tool}")

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Tool execution failed", extra={"tool": tool})
        raise HTTPException(status_code=500, detail=f"Tool execution failed: {str(e)}") from e
