import time
from types import SimpleNamespace

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from app.config import get_settings
from app.services import firebase_auth

PROJECT = "demo-project"
LONG = "x" * 30


@pytest.fixture(scope="module")
def key():
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


@pytest.fixture
def fb(monkeypatch, key):
    """Turns Firebase mode on and lets the test sign tokens with its own key instead of Google's."""
    monkeypatch.setattr(get_settings(), "firebase_project_id", PROJECT)
    monkeypatch.setattr(firebase_auth, "_jwks",
                        lambda: SimpleNamespace(get_signing_key_from_jwt=lambda tok: SimpleNamespace(key=key.public_key())))


def token(key, signer=None, **over):
    now = int(time.time())
    claims = {"iss": f"https://securetoken.google.com/{PROJECT}", "aud": PROJECT, "sub": "uid1", "iat": now, "exp": now + 3600,
              "email": "alice@example.com", "email_verified": True, "name": "Alice A"}
    claims.update(over)
    return jwt.encode(claims, signer or key, algorithm="RS256", headers={"kid": "k1"})


def test_not_configured(client):
    assert client.get("/auth/config").json() == {"firebase": False, "local_auth": True}
    assert client.post("/auth/firebase", json={"id_token": LONG}).status_code == 503


def test_first_login_creates_user_then_reuses(client, fb, key):
    email = f"fb{time.time_ns()}@example.com"
    r = client.post("/auth/firebase", json={"id_token": token(key, email=email.upper()), "role": "deaf_mute"})
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["is_new_user"] is True and d["user"]["email"] == email and d["user"]["role"] == "deaf_mute" and d["user"]["full_name"] == "Alice A"
    me = client.get("/users/me", headers={"Authorization": f"Bearer {d['access_token']}"})
    assert me.status_code == 200 and me.json()["email"] == email
    again = client.post("/auth/firebase", json={"id_token": token(key, email=email)}).json()
    assert again["is_new_user"] is False and again["user"]["id"] == d["user"]["id"]
    # the new user can change role later
    up = client.patch("/users/me", json={"role": "hearing"}, headers={"Authorization": f"Bearer {d['access_token']}"})
    assert up.json()["role"] == "hearing"


def test_rejects_bad_tokens(client, fb, key):
    other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    cases = {
        "unverified email": (token(key, email_verified=False, email="u@example.com"), 403),
        "no email": (token(key, email=None), 401),
        "wrong project": (token(key, aud="other-project"), 401),
        "wrong issuer": (token(key, iss="https://evil.example.com"), 401),
        "expired": (token(key, exp=int(time.time()) - 3600), 401),
        "wrong signing key": (token(key, signer=other), 401),
        "garbage": ("not-a-token-at-all-not-a-token", 401),
    }
    for name, (tok, status) in cases.items():
        r = client.post("/auth/firebase", json={"id_token": tok})
        assert r.status_code == status, (name, r.status_code, r.text)
    assert "verify your email" in client.post("/auth/firebase", json={"id_token": cases["unverified email"][0]}).json()["detail"]


def test_local_auth_switched_off_when_firebase_on(client, fb, monkeypatch):
    assert client.get("/auth/config").json() == {"firebase": True, "local_auth": False}
    body = {"full_name": "No One", "email": f"x{time.time_ns()}@example.com", "password": "secret123"}
    assert client.post("/auth/register", json=body).status_code == 403
    assert client.post("/auth/login", json={"email": body["email"], "password": "secret123"}).status_code == 403
    monkeypatch.setattr(get_settings(), "allow_local_auth", True)
    assert client.post("/auth/register", json=body).status_code == 201
