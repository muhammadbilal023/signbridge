import os
import tempfile

_tmp = tempfile.mkdtemp()
os.environ.update(DATABASE_URL="sqlite://", SECRET_KEY="test-secret", MEDIA_DIR=_tmp + "/media", MODELS_DIR=_tmp + "/models",
                  ADMIN_EMAIL="admin@example.com", ADMIN_PASSWORD="adminpass1", LLM_BASE_URL="", LLM_API_KEY="", LLM_MODEL="")

import itertools  # noqa: E402

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

_n = itertools.count(1)


@pytest.fixture(scope="session")
def client():
    with TestClient(app) as c:
        yield c


def make_user(client, role="hearing", prefix="user"):
    email = f"{prefix}{next(_n)}@example.com"
    r = client.post("/auth/register", json={"full_name": "Test User", "email": email, "password": "secret123", "role": role})
    assert r.status_code == 201, r.text
    data = r.json()
    return {"id": data["user"]["id"], "email": email, "token": data["access_token"],
            "headers": {"Authorization": f"Bearer {data['access_token']}"}}


def admin_headers(client):
    r = client.post("/auth/login", json={"email": "admin@example.com", "password": "adminpass1"})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def user(client):
    return make_user(client)
