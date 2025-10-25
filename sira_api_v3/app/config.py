"""Application configuration and shared settings for sira_api_v3."""
from __future__ import annotations

import logging
from functools import lru_cache
from typing import Any

from pydantic import AnyHttpUrl, Field
from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger("sira_api_v3.config")


class Settings(BaseSettings):
    """Runtime configuration loaded from environment variables."""

    app_name: str = "sira_api_v3"
    api_version: str = "v1"
    environment: str = Field(default="development", alias="ENVIRONMENT")
    port: int = Field(default=8791, alias="PORT")

    redis_url: str = Field(..., alias="REDIS_URL")
    qdrant_url: AnyHttpUrl = Field(..., alias="QDRANT_URL")
    qdrant_api_key: str | None = Field(default=None, alias="QDRANT_API_KEY")

    # Google OAuth2
    google_client_id: str | None = Field(default=None, alias="GOOGLE_CLIENT_ID")
    google_client_secret: str | None = Field(default=None, alias="GOOGLE_CLIENT_SECRET")
    google_project_id: str | None = Field(default=None, alias="GOOGLE_PROJECT_ID")
    oauth_redirect_uri: str | None = Field(default=None, alias="OAUTH_REDIRECT_URI")

    openai_api_key: str | None = Field(default=None, alias="OPENAI_API_KEY")
    serpapi_api_key: str | None = Field(default=None, alias="SERPAPI_API_KEY")
    perplexity_api_key: str | None = Field(default=None, alias="PERPLEXITY_API_KEY")
    openweather_api_key: str | None = Field(default=None, alias="OPENWEATHER_API_KEY")
    news_api_key: str | None = Field(default=None, alias="NEWS_API_KEY")
    gmail_sender: str | None = Field(default=None, alias="GMAIL_SENDER")

    twilio_account_sid: str | None = Field(default=None, alias="TWILIO_ACCOUNT_SID")
    twilio_auth_token: str | None = Field(default=None, alias="TWILIO_AUTH_TOKEN")
    twilio_phone_number: str | None = Field(default=None, alias="TWILIO_PHONE_NUMBER")
    sira_phone_enabled: bool = Field(default=False, alias="SIRA_PHONE_ENABLED")

    default_timezone: str = Field(default="Europe/Zurich", alias="DEFAULT_TIMEZONE")
    request_timeout_seconds: int = Field(default=30, alias="REQUEST_TIMEOUT_SECONDS")
    http_timeout_seconds: int = Field(default=25, alias="HTTP_TIMEOUT_SECONDS")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_prefix="",
        env_nested_delimiter="__",
        extra="allow",
        case_sensitive=False,
    )


@lru_cache
def get_settings() -> Settings:
    """Return a cached instance of the loaded settings."""

    settings = Settings()
    logger.debug(
        "Settings loaded",
        extra={
            "app_name": settings.app_name,
            "environment": settings.environment,
            "port": settings.port,
        },
    )
    return settings


def configure_logging(level: int | str | None = None) -> None:
    """Configure application-wide logging only once."""

    effective_level: int
    if level is None:
        effective_level = logging.INFO
    else:
        effective_level = (logging.getLevelName(level) if isinstance(level, str) else level)  # type: ignore[arg-type]

    if logging.getLogger().handlers:
        # Logging already configured elsewhere (e.g., by UVicorn)
        logging.getLogger().setLevel(effective_level)
        return

    logging.basicConfig(
        level=effective_level,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )


def get_logging_kwargs(extra: dict[str, Any] | None = None) -> dict[str, Any]:
    """Helper to attach structured context to log statements."""

    return {"extra": extra or {}}
