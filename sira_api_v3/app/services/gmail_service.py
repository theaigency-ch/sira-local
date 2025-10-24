"""Gmail service with direct Google API integration."""
from __future__ import annotations

import base64
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Any

from googleapiclient.discovery import build

from app.config import Settings
from app.core.google_auth import get_google_credentials
from app.schemas.email_schema import EmailGetRequest, EmailReplyRequest, EmailSendRequest

logger = logging.getLogger("sira_api_v3.services.gmail")


class GmailService:
    """Direct Gmail API integration."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._service = None

    def _get_service(self):
        """Lazy-load Gmail API service."""
        if not self._service:
            creds = get_google_credentials(self._settings)
            self._service = build("gmail", "v1", credentials=creds)
        return self._service

    async def send_email(self, request: EmailSendRequest) -> dict[str, Any]:
        """Send email via Gmail API."""
        service = self._get_service()

        message = MIMEMultipart()
        message["to"] = ", ".join([r.email for r in request.to])
        message["subject"] = request.subject
        if request.cc:
            message["cc"] = ", ".join([r.email for r in request.cc])
        if request.bcc:
            message["bcc"] = ", ".join([r.email for r in request.bcc])
        if request.reply_to:
            message["reply-to"] = request.reply_to

        message.attach(MIMEText(request.body, "plain"))

        raw = base64.urlsafe_b64encode(message.as_bytes()).decode()
        result = service.users().messages().send(userId="me", body={"raw": raw}).execute()

        logger.info("Email sent", extra={"message_id": result["id"]})
        return {"ok": True, "messageId": result["id"], "threadId": result.get("threadId")}

    async def reply_email(self, request: EmailReplyRequest) -> dict[str, Any]:
        """Reply to email thread."""
        service = self._get_service()

        message = MIMEText(request.body)
        message["In-Reply-To"] = request.message_id
        message["References"] = request.message_id

        raw = base64.urlsafe_b64encode(message.as_bytes()).decode()
        result = (
            service.users()
            .messages()
            .send(userId="me", body={"raw": raw, "threadId": request.thread_id})
            .execute()
        )

        logger.info("Email reply sent", extra={"message_id": result["id"]})
        return {"ok": True, "messageId": result["id"], "threadId": result["threadId"]}

    async def list_emails(self, request: EmailGetRequest) -> dict[str, Any]:
        """List emails with optional filter."""
        service = self._get_service()

        query_params = {"userId": "me", "maxResults": request.limit}
        if request.filter:
            query_params["q"] = request.filter
        if request.label_ids:
            query_params["labelIds"] = list(request.label_ids)

        results = service.users().messages().list(**query_params).execute()
        messages = results.get("messages", [])

        emails = []
        for msg in messages:
            full_msg = service.users().messages().get(userId="me", id=msg["id"]).execute()
            headers = {h["name"]: h["value"] for h in full_msg["payload"]["headers"]}
            emails.append(
                {
                    "id": full_msg["id"],
                    "threadId": full_msg["threadId"],
                    "from": headers.get("From", ""),
                    "subject": headers.get("Subject", ""),
                    "snippet": full_msg.get("snippet", ""),
                    "date": headers.get("Date", ""),
                    "unread": "UNREAD" in full_msg.get("labelIds", []),
                }
            )

        logger.info("Emails listed", extra={"count": len(emails)})
        return {"ok": True, "count": len(emails), "emails": emails}
