"""Weather retrieval services."""
from __future__ import annotations

from app.schemas.weather_schema import WeatherGetRequest
from app.services.base import ToolService


class WeatherService(ToolService):
    async def get_weather(self, request: WeatherGetRequest):
        return await self._call_tool("weather.get", request.to_payload())
