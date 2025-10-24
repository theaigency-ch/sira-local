"""Email service with direct Gmail API integration."""
from __future__ import annotations

from app.schemas.email_schema import EmailGetRequest, EmailReplyRequest, EmailSendRequest
from app.services.gmail_service import GmailService


class EmailService(GmailService):
    """High-level operations for Gmail-related agent tools."""

    pass


__all__ = ["EmailService"]
