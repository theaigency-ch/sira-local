"""News retrieval service."""
from __future__ import annotations

from app.schemas.news_schema import NewsGetRequest
from app.services.base import ToolService


class NewsService(ToolService):
    async def get_news(self, request: NewsGetRequest):
        return await self._call_tool("news.get", request.to_payload())
