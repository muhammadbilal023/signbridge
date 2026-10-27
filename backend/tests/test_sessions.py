from tests.conftest import make_user


def test_session_lifecycle(client):
    a, b, c = make_user(client), make_user(client), make_user(client)
    s = client.post("/sessions", headers=a["headers"])
    assert s.status_code == 201
    code = s.json()["code"]
    assert code.startswith("SB-") and s.json()["status"] == "waiting"

    assert client.get(f"/sessions/{code}", headers=c["headers"]).status_code == 403
    j = client.post("/sessions/join", json={"code": code.lower()}, headers=b["headers"])
    assert j.status_code == 200 and j.json()["status"] == "active" and len(j.json()["participants"]) == 2
    assert client.post("/sessions/join", json={"code": code}, headers=b["headers"]).status_code == 200  # rejoin is fine
    assert client.post("/sessions/join", json={"code": code}, headers=c["headers"]).status_code == 409  # one-to-one only
    assert client.post("/sessions/join", json={"code": "SB-000000"}, headers=c["headers"]).status_code == 404

    assert client.get(f"/sessions/{code}/captions", headers=a["headers"]).json() == []
    assert len(client.get("/sessions", headers=a["headers"]).json()) == 1
    ended = client.post(f"/sessions/{code}/end", headers=b["headers"])
    assert ended.status_code == 200 and ended.json()["status"] == "ended" and ended.json()["ended_at"]
    assert client.post("/sessions/join", json={"code": code}, headers=c["headers"]).status_code == 404
