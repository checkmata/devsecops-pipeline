import pytest
from httpx import AsyncClient, ASGITransport

from app.main import app


@pytest.fixture
async def client():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


@pytest.fixture
async def auth_token(client):
    """Obtain a valid JWT token for the admin user."""
    response = await client.post(
        "/auth/token",
        data={"username": "admin", "password": "password123"},
    )
    return response.json()["access_token"]


# ── Health / readiness ────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_health_check(client):
    response = await client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "healthy"
    assert "version" in body


@pytest.mark.asyncio
async def test_readiness_check(client):
    response = await client.get("/ready")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"


@pytest.mark.asyncio
async def test_metrics_endpoint_returns_prometheus_format(client):
    response = await client.get("/metrics")
    assert response.status_code == 200
    assert b"http_requests_total" in response.content


# ── Authentication ────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_login_success(client):
    response = await client.post(
        "/auth/token",
        data={"username": "admin", "password": "password123"},
    )
    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_login_wrong_password(client):
    response = await client.post(
        "/auth/token",
        data={"username": "admin", "password": "wrongpassword"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_login_unknown_user(client):
    response = await client.post(
        "/auth/token",
        data={"username": "ghost", "password": "whatever"},
    )
    assert response.status_code == 401


# ── Protected routes ──────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_current_user(client, auth_token):
    response = await client.get(
        "/users/me",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["username"] == "admin"
    assert "email" in body


@pytest.mark.asyncio
async def test_get_current_user_no_token(client):
    response = await client.get("/users/me")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_get_current_user_invalid_token(client):
    response = await client.get(
        "/users/me",
        headers={"Authorization": "Bearer this-is-not-a-valid-token"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_get_item(client, auth_token):
    response = await client.get(
        "/items/42",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert response.status_code == 200
    assert response.json()["item_id"] == 42


@pytest.mark.asyncio
async def test_get_item_no_token(client):
    response = await client.get("/items/1")
    assert response.status_code == 401
