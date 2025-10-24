"""Shared logic for executing tool actions (n8n bridge or direct integrations)."""
from __future__ import annotations

import logging
from typing import Any

import httpx

from app.config import Settings, get_logging_kwargs

logger = logging.getLogger("sira_api_v3.services.tool_executor")


class ToolExecutionError(RuntimeError):
    """Raised when a downstream tool execution fails."""

    def __init__(self, tool: str, status_code: int, detail: Any) -> None:
        super().__init__(f"Tool '{tool}' failed with status {status_code}: {detail}")
        self.tool = tool
        self.status_code = status_code
        self.detail = detail


class ToolExecutor:
    """Simple HTTP client for delegating tool executions."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client = httpx.AsyncClient(timeout=settings.http_timeout_seconds)

    async def execute(self, tool: str, payload: dict[str, Any]) -> dict[str, Any]:
        if not self._settings.n8n_task_url:
            logger.warning(
                "N8N_TASK_URL not configured; returning payload as stub response",
                **get_logging_kwargs({"tool": tool}),
            )
            return {"ok": True, "tool": tool, "payload": payload}

        request_payload = {"tool": tool} | payload
        logger.debug("Dispatching tool", **get_logging_kwargs({"tool": tool}))

        response = await self._client.post(self._settings.n8n_task_url, json=request_payload)
        if response.status_code >= 400:
            detail = response.text
            logger.error(
                "Tool execution failed",
                **get_logging_kwargs({"tool": tool, "status_code": response.status_code, "detail": detail}),
            )
            raise ToolExecutionError(tool, response.status_code, detail)
        data = response.json()
        logger.info("Tool executed successfully", **get_logging_kwargs({"tool": tool}))
        return data

    async def aclose(self) -> None:
        await self._client.aclose()


async def execute_tool(tool: str, payload: dict[str, Any], settings: Settings) -> dict[str, Any]:
    executor = ToolExecutor(settings)
    try:
        return await executor.execute(tool, payload)
    finally:
        await executor.aclose()
