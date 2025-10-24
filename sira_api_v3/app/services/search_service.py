"""Search-related services with direct API integration."""
from __future__ import annotations

from app.schemas.search_schema import PerplexitySearchRequest
from app.services.serpapi_service import SerpAPIService
from app.services.webfetch_service import WebFetchService as WebFetchServiceImpl


class WebSearchService(SerpAPIService):
    """Web search using SerpAPI."""

    pass


class WebFetchService(WebFetchServiceImpl):
    """Web page fetching using httpx."""

    pass


class PerplexityService:
    """Perplexity search - placeholder for future implementation."""

    def __init__(self, settings):
        self._settings = settings

    async def search(self, request: PerplexitySearchRequest):
        # TODO: Implement Perplexity API if key available
        return {"ok": False, "error": "Perplexity API not yet implemented"}
