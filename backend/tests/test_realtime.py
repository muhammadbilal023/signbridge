import asyncio
import socket
import threading
import time

import pytest
import socketio
import uvicorn

from app.main import app
from tests.conftest import make_user


@pytest.fixture(scope="module")
def server_url():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    server = uvicorn.Server(uvicorn.Config(app, host="127.0.0.1", port=port, log_level="warning"))
    th = threading.Thread(target=server.run, daemon=True)
    th.start()
    for _ in range(100):
        if server.started:
            break
        time.sleep(0.05)
    yield f"http://127.0.0.1:{port}"
    server.should_exit = True
    th.join(timeout=5)


def test_signaling_captions_chat_end(client, server_url):
    a, b = make_user(client, "deaf_mute"), make_user(client)
    code = client.post("/sessions", headers=a["headers"]).json()["code"]
    client.post("/sessions/join", json={"code": code}, headers=b["headers"])
    outsider = make_user(client)

    async def scenario():
        ca, cb = socketio.AsyncClient(), socketio.AsyncClient()
        got = {k: asyncio.Event() for k in ("offer", "caption_b", "chat_b", "ended", "emotion", "translated")}
        store = {}
        cb.on("offer", lambda d: (store.update(offer=d), got["offer"].set()))
        cb.on("caption", lambda d: (store.update(caption=d), got["caption_b"].set()))
        cb.on("chat_message", lambda d: (store.update(chat=d), got["chat_b"].set()))
        cb.on("session_ended", lambda d: got["ended"].set())
        cb.on("emotion_update", lambda d: (store.update(emotion=d), got["emotion"].set()))
        cb.on("translated_text", lambda d: (store.update(tr=d), got["translated"].set()))

        with pytest.raises(socketio.exceptions.ConnectionError):
            await socketio.AsyncClient().connect(server_url, auth={"token": "bad"})

        await ca.connect(server_url, auth={"token": a["token"]})
        await cb.connect(server_url, auth={"token": b["token"]})
        bad = socketio.AsyncClient()
        await bad.connect(server_url, auth={"token": outsider["token"]})
        assert (await bad.call("join_room", {"code": code}))["ok"] is False   # not a participant
        await bad.disconnect()

        assert (await ca.call("offer", {"sdp": "x"}))["ok"] is False           # must join room first
        assert (await ca.call("join_room", {"code": code}))["ok"] is True
        assert (await cb.call("join_room", {"code": code}))["ok"] is True

        await ca.call("offer", {"sdp": "v=0"})
        await asyncio.wait_for(got["offer"].wait(), 3)
        assert store["offer"] == {"sdp": "v=0"}

        assert (await ca.call("caption", {"text": "hello there", "language": "en"}))["ok"] is True
        await asyncio.wait_for(got["caption_b"].wait(), 3)
        assert store["caption"]["text"] == "hello there"
        await ca.call("chat_message", {"body": "hi"})
        await asyncio.wait_for(got["chat_b"].wait(), 3)
        await ca.call("emotion_update", {"label": "happy", "confidence": 0.8})
        await asyncio.wait_for(got["emotion"].wait(), 3)
        await ca.call("translated_text", {"text": "I need help", "language": "en"})
        await asyncio.wait_for(got["translated"].wait(), 3)

        assert (await ca.call("end_session", {}))["ok"] is True
        await asyncio.wait_for(got["ended"].wait(), 3)
        await ca.disconnect()
        await cb.disconnect()

    asyncio.run(scenario())
    caps = client.get(f"/sessions/{code}/captions", headers=a["headers"]).json()
    assert [c["text"] for c in caps] == ["hello there", "I need help"]
    assert client.get(f"/sessions/{code}/chat", headers=b["headers"]).json()[0]["body"] == "hi"
    assert client.get(f"/sessions/{code}", headers=a["headers"]).json()["status"] == "ended"
