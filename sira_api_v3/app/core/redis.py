"""Redis connection helpers."""
from __future__ import annotations

import logging

import redis
import redis.asyncio as aioredis

logger = logging.getLogger("sira_api_v3.core.redis")


async def create_redis_client(url: str) -> aioredis.Redis:
    client = aioredis.from_url(url, decode_responses=True)
    try:
        await client.ping()
    except Exception:
        logger.exception("Redis ping failed", extra={"redis_url": url})
        raise
    logger.info("Connected to Redis", extra={"redis_url": url})
    return client


def get_redis_client(app_state) -> aioredis.Redis:
    client = getattr(app_state, "redis", None)
    if client is None:
        raise RuntimeError("Redis client not configured on application state")
    return client


def get_sync_redis_client() -> redis.Redis:
    """Get synchronous Redis client for OAuth token storage."""
    from app.config import get_settings
    settings = get_settings()
    if not settings.redis_url:
        raise RuntimeError("Redis URL not configured")
    client = redis.from_url(settings.redis_url, decode_responses=True)
    return client
