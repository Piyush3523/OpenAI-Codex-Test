from functools import lru_cache
from os import getenv


class Settings:
    app_name: str = getenv("APP_NAME", "secure-observability-api")
    app_version: str = getenv("APP_VERSION", "0.1.0")
    environment: str = getenv("ENVIRONMENT", "development")
    database_url: str = getenv(
        "DATABASE_URL",
        "postgresql://platform:platform@postgres:5432/platform",
    )
    redis_url: str = getenv("REDIS_URL", "redis://redis:6379/0")
    cors_origins: list[str] = [
        origin.strip()
        for origin in getenv(
            "CORS_ORIGINS",
            "http://localhost:5000,http://localhost:5173",
        ).split(",")
        if origin.strip()
    ]
    log_level: str = getenv("LOG_LEVEL", "info")


@lru_cache
def get_settings() -> Settings:
    return Settings()

