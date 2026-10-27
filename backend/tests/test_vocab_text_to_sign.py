from tests.conftest import admin_headers


def test_seeded_vocabulary(client):
    words = client.get("/vocabulary").json()
    assert len(words) >= 25
    assert any(w["english_text"] == "how are you" for w in words)
    assert client.get("/vocabulary", params={"q": "wat"}).json()[0]["english_text"] == "water"


def test_text_to_sign_phrases_and_unknown(client, user):
    r = client.post("/text-to-sign", json={"text": "Hello, how are you? pizza"}, headers=user["headers"])
    assert r.status_code == 200
    items = r.json()["playlist"]
    assert [(i["word"], i["known"]) for i in items] == [("hello", True), ("how are you", True), ("pizza", False)]
    hist = client.get("/history", headers=user["headers"]).json()
    assert hist[0]["mode"] == "text_to_sign" and "hello" in hist[0]["output_text"]


def test_urdu_text(client, user):
    r = client.post("/text-to-sign", json={"text": "شکریہ"}, headers=user["headers"])
    assert r.json()["playlist"][0] == {"word": "شکریہ", "known": True, "clip_url": None}


def test_admin_upload_clip_and_playlist_url(client, user):
    assert client.post("/vocabulary", json={"english_text": "tea"}, headers=user["headers"]).status_code == 403
    adm = admin_headers(client)
    word = client.post("/vocabulary", json={"english_text": "Tea", "urdu_text": "چائے"}, headers=adm)
    assert word.status_code == 201
    wid = word.json()["id"]
    assert client.post("/vocabulary", json={"english_text": "tea"}, headers=adm).status_code == 409
    bad = client.post(f"/vocabulary/{wid}/clips", files={"file": ("a.txt", b"x", "text/plain")}, headers=adm)
    assert bad.status_code == 415
    ok = client.post(f"/vocabulary/{wid}/clips", files={"file": ("tea.mp4", b"\x00\x00\x00 ftypmp42", "video/mp4")},
                     data={"source_language": "PSL"}, headers=adm)
    assert ok.status_code == 201 and len(ok.json()["clip_urls"]) == 1
    url = ok.json()["clip_urls"][0]
    assert client.get(url).status_code == 200
    r = client.post("/text-to-sign", json={"text": "tea"}, headers=user["headers"]).json()
    assert r["playlist"][0]["clip_url"] == url and r["clips_available"] == 1
