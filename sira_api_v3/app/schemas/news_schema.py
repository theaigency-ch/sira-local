"""Schemas for news retrieval tools."""
from __future__ import annotations

from typing import Sequence

from pydantic import BaseModel, Field


class NewsGetRequest(BaseModel):
    category: str | None = Field(default=None, max_length=50)
    country: str | None = Field(default=None, max_length=2, description="ISO 3166-1 alpha-2 code")
    language: str | None = Field(default=None, max_length=2)
    keywords: Sequence[str] | None = None
    limit: int = Field(default=5, ge=1, le=20)

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {"limit": self.limit}
        if self.category:
            payload["category"] = self.category
        if self.country:
            payload["country"] = self.country
        if self.language:
            payload["language"] = self.language
        if self.keywords:
            payload["keywords"] = list(self.keywords)
        return payload
