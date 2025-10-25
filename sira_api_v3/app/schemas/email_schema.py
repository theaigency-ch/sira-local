"""Schemas for email-related endpoints."""
from __future__ import annotations

from typing import Iterable, Sequence

from pydantic import BaseModel, EmailStr, Field


class EmailRecipient(BaseModel):
    email: EmailStr
    name: str | None = Field(default=None, max_length=200)


class EmailAttachment(BaseModel):
    model_config = {"populate_by_name": True}
    
    filename: str = Field(max_length=255)
    content: str = Field(description="Base64 encoded attachment content")
    mime_type: str | None = Field(default=None, alias="mimeType")


class EmailSendRequest(BaseModel):
    model_config = {"populate_by_name": True}
    
    to: Sequence[EmailRecipient] = Field(min_length=1)
    subject: str = Field(max_length=240)
    body: str
    cc: Sequence[EmailRecipient] | None = None
    bcc: Sequence[EmailRecipient] | None = None
    attachments: Sequence[EmailAttachment] | None = None
    reply_to: EmailStr | None = Field(default=None, alias="replyTo")

    def to_payload(self) -> dict[str, object]:
        return {
            "to": [recipient.model_dump(by_alias=True) for recipient in self.to],
            "subject": self.subject,
            "body": self.body,
            **({"cc": [r.model_dump(by_alias=True) for r in self.cc]} if self.cc else {}),
            **({"bcc": [r.model_dump(by_alias=True) for r in self.bcc]} if self.bcc else {}),
            **({"attachments": [att.model_dump(by_alias=True) for att in self.attachments]} if self.attachments else {}),
            **({"reply_to": self.reply_to} if self.reply_to else {}),
        }


class EmailReplyRequest(BaseModel):
    model_config = {"populate_by_name": True}
    
    thread_id: str = Field(max_length=256, alias="threadId")
    message_id: str = Field(max_length=256, alias="messageId")
    body: str
    cc: Sequence[EmailRecipient] | None = None
    bcc: Sequence[EmailRecipient] | None = None

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {
            "thread_id": self.thread_id,
            "message_id": self.message_id,
            "body": self.body,
        }
        if self.cc:
            payload["cc"] = [recipient.model_dump(by_alias=True) for recipient in self.cc]
        if self.bcc:
            payload["bcc"] = [recipient.model_dump(by_alias=True) for recipient in self.bcc]
        return payload


class EmailGetRequest(BaseModel):
    model_config = {"populate_by_name": True}
    
    filter: str | None = Field(default=None, max_length=500)
    limit: int = Field(default=5, ge=1, le=50)
    label_ids: Sequence[str] | None = Field(default=None, alias="labelIds")

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {"limit": self.limit}
        if self.filter:
            payload["filter"] = self.filter
        if self.label_ids:
            payload["label_ids"] = list(self.label_ids)
        return payload
