"""Main FastAPI application for sira_api_v3."""
from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import configure_logging, get_settings
from app.core import register_shutdown_event, register_startup_event
from app.routes import register_routes

logger = logging.getLogger("sira_api_v3.app")


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging()

    app = FastAPI(
        title=settings.app_name,
        version=settings.api_version,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url=f"/openapi/{settings.api_version}.json",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_startup_event(app)
    register_shutdown_event(app)
    register_routes(app)

    logger.info("FastAPI application initialized")
    return app


app = create_app()
