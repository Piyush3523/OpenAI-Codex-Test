from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import UTC, datetime

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from psycopg.errors import UniqueViolation

from app.config import get_settings
from app.database import (
    create_user,
    database_ready,
    init_database,
    list_users,
    platform_summary,
    redis_ready,
)
from app.metrics import USER_CREATIONS, MetricsMiddleware, metrics_response
from app.schemas import (
    HealthResponse,
    PlatformSummary,
    ReadinessResponse,
    UserCreate,
    UserResponse,
)

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    init_database()
    yield

app = FastAPI(
    title="Secure Kubernetes Observability Platform API",
    version=settings.app_version,
    docs_url="/docs",
    redoc_url=None,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)
app.add_middleware(MetricsMiddleware)


@app.get("/health", response_model=HealthResponse, tags=["system"])
def health() -> HealthResponse:
    return HealthResponse(
        status="healthy",
        timestamp=datetime.now(UTC),
        service=settings.app_name,
        version=settings.app_version,
    )


@app.get("/ready", response_model=ReadinessResponse, tags=["system"])
def ready() -> ReadinessResponse:
    database = database_ready()
    cache = redis_ready()
    if not database or not cache:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"status": "degraded", "database": database, "redis": cache},
        )
    return ReadinessResponse(status="ready", database=database, redis=cache)


@app.get("/metrics", include_in_schema=False)
def metrics():
    return metrics_response()


@app.post(
    "/users",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["users"],
)
def add_user(payload: UserCreate) -> UserResponse:
    try:
        user = create_user(payload.name, str(payload.email))
    except UniqueViolation as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this email already exists.",
        ) from exc
    USER_CREATIONS.inc()
    return UserResponse(**user)


@app.get("/users", response_model=list[UserResponse], tags=["users"])
def users() -> list[UserResponse]:
    return [UserResponse(**user) for user in list_users()]


@app.get("/observability/summary", response_model=PlatformSummary, tags=["platform"])
def summary() -> PlatformSummary:
    return PlatformSummary(**platform_summary())
