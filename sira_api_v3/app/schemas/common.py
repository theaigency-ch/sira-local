"""Shared schema definitions."""
from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class ToolExecutionResponse(BaseModel):
    """Standard response envelope for tool invocations."""

    ok: bool = Field(default=True, description="Indicates if the downstream tool succeeded.")
    data: Any = Field(default_factory=dict, description="Payload returned by the tool executor.")
