"""News routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import get_news_service
from app.schemas.common import ToolExecutionResponse
from app.schemas.news_schema import NewsGetRequest
from app.services.news_service import NewsService
from app.services.tool_executor import ToolExecutionError

router = APIRouter()


@router.post("/get", response_model=ToolExecutionResponse)
async def get_news(
    request: NewsGetRequest,
    service: NewsService = Depends(get_news_service),
) -> ToolExecutionResponse:
    try:
        data = await service.get_news(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)
