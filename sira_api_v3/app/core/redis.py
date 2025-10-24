"""Redis connection helpers."""
from __future__ import annotations

import logging

import redis.asyncio as redis

logger = logging.getLogger("sira_api_v3.core.redis")


async def create_redis_client(url: str) -> redis.Redis:
    client = redis.from_url(url, decode_responses=True)
    try:
        await client.ping()
    except Exception:
        logger.exception("Redis ping failed", extra={"redis_url": url})
        raise
    logger.info("Connected to Redis", extra={"redis_url": url})
    return client


def get_redis_client(app_state) -> redis.Redis:
    client = getattr(app_state, "redis", None)
    if client is None:
        raise RuntimeError("Redis client not configured on application state")
    return client
