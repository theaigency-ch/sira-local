"""Schemas for contact-related actions."""
from __future__ import annotations

from typing import Sequence

from pydantic import BaseModel, EmailStr, Field


class ContactFindRequest(BaseModel):
    query: str = Field(max_length=200)
    limit: int = Field(default=5, ge=1, le=50)

    def to_payload(self) -> dict[str, object]:
        return {"query": self.query, "limit": self.limit}


class ContactUpsertRequest(BaseModel):
    email: EmailStr
    first_name: str | None = Field(default=None, alias="firstName")
    last_name: str | None = Field(default=None, alias="lastName")
    phone: str | None = None
    company: str | None = None
    tags: Sequence[str] | None = None

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {"email": self.email}
        if self.first_name:
            payload["first_name"] = self.first_name
        if self.last_name:
            payload["last_name"] = self.last_name
        if self.phone:
            payload["phone"] = self.phone
        if self.company:
            payload["company"] = self.company
        if self.tags:
            payload["tags"] = list(self.tags)
        return payload
