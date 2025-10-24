"""Qdrant client helpers."""
from __future__ import annotations

import logging
from typing import Optional

from qdrant_client import QdrantClient

logger = logging.getLogger("sira_api_v3.core.qdrant")


def create_qdrant_client(url: str, api_key: Optional[str] = None) -> QdrantClient:
    try:
        # Convert Pydantic HttpUrl to string if needed
        url_str = str(url) if hasattr(url, '__str__') else url
        client = QdrantClient(url=url_str, api_key=api_key)
        client.get_collections()
    except Exception:
        logger.exception("Failed to connect to Qdrant", extra={"qdrant_url": str(url)})
        raise
    logger.info("Connected to Qdrant", extra={"qdrant_url": str(url)})
    return client


def get_qdrant_client(app_state) -> QdrantClient:
    client = getattr(app_state, "qdrant", None)
    if client is None:
        raise RuntimeError("Qdrant client not configured on application state")
    return client