from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class HealthResponse(BaseModel):
    status: str
    timestamp: datetime
    service: str
    version: str


class ReadinessResponse(BaseModel):
    status: str
    database: bool
    redis: bool


class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    email: EmailStr
    created_at: datetime


class ServiceStatus(BaseModel):
    name: str
    status: str
    target: str


class PlatformSummary(BaseModel):
    timestamp: datetime
    services: list[ServiceStatus]
    kpis: dict[str, int | str]

