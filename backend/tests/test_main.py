from datetime import UTC, datetime
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_response() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "healthy"
    assert payload["service"] == "secure-observability-api"


def test_readiness_reports_degraded_dependency() -> None:
    with patch("app.main.database_ready", return_value=True), patch(
        "app.main.redis_ready", return_value=False
    ):
        response = client.get("/ready")

    assert response.status_code == 503
    assert response.json()["detail"]["redis"] is False


def test_summary_shape() -> None:
    summary = {
        "timestamp": datetime.now(UTC).isoformat(),
        "services": [
            {"name": "api", "status": "healthy", "target": "http://api:8000"}
        ],
        "kpis": {
            "registered_users": 0,
            "healthy_services": 1,
            "policy_mode": "enforce",
            "environment": "test",
        },
    }
    with patch("app.main.platform_summary", return_value=summary):
        response = client.get("/observability/summary")

    assert response.status_code == 200
    assert response.json()["kpis"]["policy_mode"] == "enforce"

