"""Web fetch service for retrieving webpage content."""
from __future__ import annotations

import logging
from typing import Any

import httpx
from bs4 import BeautifulSoup

from app.config import Settings
from app.schemas.search_schema import WebFetchRequest

logger = logging.getLogger("sira_api_v3.services.webfetch")


class WebFetchService:
    """Direct web page fetching with httpx and BeautifulSoup."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def fetch(self, request: WebFetchRequest) -> dict[str, Any]:
        """Fetch and parse webpage content."""
        async with httpx.AsyncClient(timeout=self._settings.http_timeout_seconds) as client:
            response = await client.get(str(request.url))
            response.raise_for_status()

            soup = BeautifulSoup(response.text, "lxml")

            # Remove script and style elements
            for script in soup(["script", "style"]):
                script.decompose()

            # Get text
            text = soup.get_text()

            # Clean up whitespace
            lines = (line.strip() for line in text.splitlines())
            chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
            text = "\n".join(chunk for chunk in chunks if chunk)

            logger.info("Web page fetched", extra={"url": str(request.url), "length": len(text)})
            return {
                "ok": True,
                "url": str(request.url),
                "title": soup.title.string if soup.title else "",
                "content": text[:10000],  # Limit to 10k chars
                "length": len(text),
            }
