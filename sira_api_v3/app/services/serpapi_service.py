"""SerpAPI service for web search."""
from __future__ import annotations

import logging
from typing import Any

import httpx

from app.config import Settings
from app.schemas.search_schema import WebSearchRequest

logger = logging.getLogger("sira_api_v3.services.serpapi")


class SerpAPIService:
    """Direct SerpAPI integration for Google Search."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def search(self, request: WebSearchRequest) -> dict[str, Any]:
        """Perform Google search via SerpAPI."""
        if not self._settings.serpapi_api_key:
            raise RuntimeError("SERPAPI_API_KEY not configured")

        params = {
            "q": request.query,
            "api_key": self._settings.serpapi_api_key,
            "num": request.num_results,
            "safe": "active" if request.safe else "off",
            "engine": "google",
        }

        if request.location:
            params["location"] = request.location
        if request.language:
            params["hl"] = request.language

        async with httpx.AsyncClient(timeout=self._settings.http_timeout_seconds) as client:
            response = await client.get("https://serpapi.com/search", params=params)
            response.raise_for_status()
            results = response.json()

        organic_results = results.get("organic_results", [])[:request.num_results]

        formatted_results = [
            {
                "position": r.get("position"),
                "title": r.get("title"),
                "link": r.get("link"),
                "snippet": r.get("snippet"),
            }
            for r in organic_results
        ]

        logger.info("Web search completed", extra={"count": len(formatted_results)})
        return {"ok": True, "count": len(formatted_results), "results": formatted_results}
