from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

import psycopg
import redis
from psycopg.rows import dict_row

from app.config import get_settings


def _connect() -> psycopg.Connection[Any]:
    return psycopg.connect(get_settings().database_url, row_factory=dict_row)


@contextmanager
def db_connection() -> Iterator[psycopg.Connection[Any]]:
    connection = _connect()
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def init_database() -> None:
    with db_connection() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id UUID PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT UNIQUE NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """
        )


def create_user(name: str, email: str) -> dict[str, Any]:
    user_id = str(uuid4())
    with db_connection() as connection:
        row = connection.execute(
            """
            INSERT INTO users (id, name, email)
            VALUES (%s, %s, %s)
            RETURNING id::text, name, email, created_at
            """,
            (user_id, name, email),
        ).fetchone()
    return dict(row)


def list_users() -> list[dict[str, Any]]:
    with db_connection() as connection:
        rows = connection.execute(
            """
            SELECT id::text, name, email, created_at
            FROM users
            ORDER BY created_at DESC
            LIMIT 100
            """
        ).fetchall()
    return [dict(row) for row in rows]


def database_ready() -> bool:
    try:
        with db_connection() as connection:
            connection.execute("SELECT 1")
        return True
    except Exception:
        return False


def redis_ready() -> bool:
    try:
        client = redis.from_url(get_settings().redis_url, socket_timeout=2)
        return bool(client.ping())
    except Exception:
        return False


def platform_summary() -> dict[str, Any]:
    users = []
    try:
        users = list_users()
    except Exception:
        users = []

    return {
        "timestamp": datetime.now(UTC).isoformat(),
        "services": [
            {"name": "api", "status": "healthy", "target": "http://api:8000"},
            {
                "name": "postgres",
                "status": "healthy" if database_ready() else "degraded",
                "target": "postgres:5432",
            },
            {
                "name": "redis",
                "status": "healthy" if redis_ready() else "degraded",
                "target": "redis:6379",
            },
        ],
        "kpis": {
            "registered_users": len(users),
            "healthy_services": sum(
                1
                for service in [
                    True,
                    database_ready(),
                    redis_ready(),
                ]
                if service
            ),
            "policy_mode": "enforce",
            "environment": get_settings().environment,
        },
    }

