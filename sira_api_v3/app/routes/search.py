"""Search and web-related routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import (
    get_perplexity_service,
    get_web_fetch_service,
    get_web_search_service,
)
from app.schemas.common import ToolExecutionResponse
from app.schemas.search_schema import (
    PerplexitySearchRequest,
    WebFetchRequest,
    WebSearchRequest,
)
from app.services.search_service import (
    PerplexityService,
    WebFetchService,
    WebSearchService,
)
from app.services.tool_executor import ToolExecutionError

router = APIRouter()


@router.post("/web", response_model=ToolExecutionResponse)
async def web_search(
    request: WebSearchRequest,
    service: WebSearchService = Depends(get_web_search_service),
) -> ToolExecutionResponse:
    try:
        data = await service.search(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)


@router.post("/fetch", response_model=ToolExecutionResponse)
async def web_fetch(
    request: WebFetchRequest,
    service: WebFetchService = Depends(get_web_fetch_service),
) -> ToolExecutionResponse:
    try:
        data = await service.fetch(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)


@router.post("/perplexity", response_model=ToolExecutionResponse)
async def perplexity_search(
    request: PerplexitySearchRequest,
    service: PerplexityService = Depends(get_perplexity_service),
) -> ToolExecutionResponse:
    try:
        data = await service.search(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)
