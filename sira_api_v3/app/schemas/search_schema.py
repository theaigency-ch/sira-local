"""Schemas for web and search related tools."""
from __future__ import annotations

from typing import Literal, Sequence

from pydantic import BaseModel, Field, HttpUrl


class WebSearchRequest(BaseModel):
    model_config = {"populate_by_name": True}
    
    query: str = Field(max_length=500)
    location: str | None = None
    language: str | None = None
    safe: bool = Field(default=True)
    num_results: int = Field(default=5, ge=1, le=20, alias="numResults")

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {
            "query": self.query,
            "safe": self.safe,
            "num_results": self.num_results,
        }
        if self.location:
            payload["location"] = self.location
        if self.language:
            payload["language"] = self.language
        return payload


class WebFetchRequest(BaseModel):
    model_config = {"populate_by_name": True}
    
    url: HttpUrl
    render_js: bool = Field(default=False, alias="renderJs")

    def to_payload(self) -> dict[str, object]:
        return {"url": str(self.url), "render_js": self.render_js}


class PerplexitySearchRequest(BaseModel):
    query: str = Field(max_length=500)
    focus: Literal["web", "academic", "news"] | None = None
    sources: Sequence[str] | None = None

    def to_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {"query": self.query}
        if self.focus:
            payload["focus"] = self.focus
        if self.sources:
            payload["sources"] = list(self.sources)
        return payload
