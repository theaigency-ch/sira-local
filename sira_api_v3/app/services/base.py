"""Base service utilities for tool orchestration."""
from __future__ import annotations

from typing import Any

from app.config import Settings
from app.services.tool_executor import execute_tool


class ToolService:
    """Base class providing helper to execute a named tool."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def _call_tool(self, tool: str, payload: dict[str, Any]) -> dict[str, Any]:
        return await execute_tool(tool, payload, self._settings)
