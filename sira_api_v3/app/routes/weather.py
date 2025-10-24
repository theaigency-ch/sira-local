"""Weather routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import get_weather_service
from app.schemas.common import ToolExecutionResponse
from app.schemas.weather_schema import WeatherGetRequest
from app.services.tool_executor import ToolExecutionError
from app.services.weather_service import WeatherService

router = APIRouter()


@router.post("/get", response_model=ToolExecutionResponse)
async def get_weather(
    request: WeatherGetRequest,
    service: WeatherService = Depends(get_weather_service),
) -> ToolExecutionResponse:
    try:
        data = await service.get_weather(request)
    except ToolExecutionError as exc:  # pragma: no cover
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    return ToolExecutionResponse(ok=True, data=data)
