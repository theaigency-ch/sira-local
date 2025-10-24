"""Application lifecycle hooks for FastAPI app."""
from __future__ import annotations

import logging
from typing import Awaitable, Callable

from fastapi import FastAPI

from app.config import configure_logging, get_settings
from app.core.qdrant import create_qdrant_client
from app.core.redis import create_redis_client

logger = logging.getLogger("sira_api_v3.core.events")


async def _startup() -> None:
    settings = get_settings()
    configure_logging()
    logger.info("Starting sira_api_v3", extra={"environment": settings.environment})


async def _shutdown() -> None:
    logger.info("Shutting down sira_api_v3")


def register_startup_event(app: FastAPI) -> Callable[[], Awaitable[None]]:
    @app.on_event("startup")
    async def on_startup() -> None:
        await _startup()
        settings = get_settings()
        
        # Redis (optional - for memory/caching)
        try:
            app.state.redis = await create_redis_client(settings.redis_url)
            logger.info("Redis connected")
        except Exception as e:
            logger.warning(f"Redis not available: {e} - continuing without memory features")
            app.state.redis = None
        
        # Qdrant (optional - for vector search)
        try:
            app.state.qdrant = create_qdrant_client(settings.qdrant_url, settings.qdrant_api_key)
            logger.info("Qdrant connected")
        except Exception as e:
            logger.warning(f"Qdrant not available: {e} - continuing without vector search")
            app.state.qdrant = None
        
        logger.info("Startup complete")

    return on_startup


def register_shutdown_event(app: FastAPI) -> Callable[[], Awaitable[None]]:
    @app.on_event("shutdown")
    async def on_shutdown() -> None:
        await _shutdown()
        redis = getattr(app.state, "redis", None)
        if redis:
            await redis.close()
            await redis.wait_closed()
        qdrant = getattr(app.state, "qdrant", None)
        if qdrant:
            qdrant.close()
        logger.info("Infrastructure clients shut down")

    return on_shutdown
