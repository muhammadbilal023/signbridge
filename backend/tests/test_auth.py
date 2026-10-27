from tests.conftest import make_user


def test_register_login_me(client):
    u = make_user(client, role="deaf_mute")
    r = client.get("/users/me", headers=u["headers"])
    assert r.status_code == 200 and r.json()["email"] == u["email"] and r.json()["role"] == "deaf_mute"
    ok = client.post("/auth/login", json={"email": u["email"].upper(), "password": "secret123"})
    assert ok.status_code == 200 and ok.json()["access_token"]


def test_duplicate_and_validation(client, user):
    dup = client.post("/auth/register", json={"full_name": "X Y", "email": user["email"], "password": "secret123"})
    assert dup.status_code == 409
    assert client.post("/auth/register", json={"full_name": "X Y", "email": "not-an-email", "password": "secret123"}).status_code == 422
    assert client.post("/auth/register", json={"full_name": "X Y", "email": "a@example.com", "password": "123"}).status_code == 422
    assert client.post("/auth/register", json={"full_name": "X Y", "email": "b@example.com", "password": "secret123", "role": "admin"}).status_code == 422


def test_bad_login_and_protected_routes(client, user):
    assert client.post("/auth/login", json={"email": user["email"], "password": "wrongpass"}).status_code == 401
    assert client.get("/users/me").status_code == 401
    assert client.get("/users/me", headers={"Authorization": "Bearer garbage"}).status_code == 401


def test_update_profile(client, user):
    r = client.patch("/users/me", json={"full_name": "New Name", "preferred_language": "ur"}, headers=user["headers"])
    assert r.status_code == 200 and r.json()["full_name"] == "New Name" and r.json()["preferred_language"] == "ur"
