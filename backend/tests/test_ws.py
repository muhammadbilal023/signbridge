import time

import numpy as np
import pytest
from starlette.websockets import WebSocketDisconnect

from app.services.recognizer import get_recognizer

HAND, NONE = [0.5] * 126, [0.0] * 126


def send_sign(ws, start_ms, frames=10):
    t = start_ms
    for _ in range(frames):
        t += 66
        ws.send_json({"type": "landmarks", "data": HAND, "t": t})
    return t


def test_ws_requires_token(client):
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/ws/sign?token=bad"):
            pass


def test_ws_word_then_sentence_by_pause(client, user):
    get_recognizer()._demo_i = 0
    with client.websocket_connect(f"/ws/sign?token={user['token']}&lang=en") as ws:
        ready = ws.receive_json()
        assert ready["type"] == "ready" and ready["mode"] == "demo"
        t = send_sign(ws, 0)
        ws.send_json({"type": "landmarks", "data": NONE, "t": t + 700})   # pause -> word
        word = ws.receive_json()
        assert word["type"] == "word" and word["word"] == "hello"
        ws.send_json({"type": "landmarks", "data": NONE, "t": t + 2500})  # long pause -> sentence
        sent = ws.receive_json()
        assert sent["type"] == "sentence" and sent["sentence"] == "hello" and sent["source"] == "fallback"
    assert client.get("/history", headers=user["headers"]).json()[0]["output_text"] == "hello"


def test_ws_two_words_then_finish(client, user):
    get_recognizer()._demo_i = 1  # help, water
    with client.websocket_connect(f"/ws/sign?token={user['token']}") as ws:
        ws.receive_json()
        t = send_sign(ws, 0)
        ws.send_json({"type": "landmarks", "data": NONE, "t": t + 600})
        assert ws.receive_json()["word"] == "help"
        t = send_sign(ws, t + 700)
        ws.send_json({"type": "finish"})
        assert ws.receive_json()["word"] == "water"
        s = ws.receive_json()
        assert s["type"] == "sentence" and s["words"] == ["help", "water"] and s["sentence"] == "help water"


def test_ws_bad_messages(client, user):
    with client.websocket_connect(f"/ws/sign?token={user['token']}") as ws:
        ws.receive_json()
        ws.send_text("not json")
        assert ws.receive_json()["type"] == "error"
        ws.send_json({"type": "landmarks", "data": [1, 2, 3]})
        assert ws.receive_json()["type"] == "error"
        ws.send_json({"type": "finish"})
        assert ws.receive_json() == {"type": "sentence", "words": [], "sentence": "", "source": "fallback", "history_id": None}


def test_ws_emotion_demo(client, user):
    with client.websocket_connect(f"/ws/emotion?token={user['token']}") as ws:
        assert ws.receive_json() == {"type": "ready", "mode": "demo"}
        ws.send_bytes(b"fake-jpeg")
        r = ws.receive_json()
        assert r["type"] == "emotion" and r["label"] == "neutral" and r["changed"] is True


def test_recognition_status(client):
    r = client.get("/recognition/status").json()
    assert r["mode"] == "demo" and r["llm_configured"] is False


def test_ws_jpeg_frames_echo_hands_and_detect_word(client, user, monkeypatch):
    from app.config import get_settings
    from app.routers import ws as ws_mod

    s = get_settings()
    monkeypatch.setattr(s, "word_gap_seconds", 0.05)
    monkeypatch.setattr(s, "min_word_frames", 2)
    monkeypatch.setattr(ws_mod.extractor, "from_jpeg",
                        lambda data: np.full(126, 0.5, np.float32) if data == b"hand" else np.zeros(126, np.float32))
    get_recognizer()._demo_i = 0
    with client.websocket_connect(f"/ws/sign?token={user['token']}") as ws:
        ws.receive_json()
        for _ in range(3):
            ws.send_bytes(b"hand")
            h = ws.receive_json()
            assert h["type"] == "hands" and h["present"] is True and len(h["points"]) == 126
        time.sleep(0.15)
        ws.send_bytes(b"empty")
        assert ws.receive_json()["present"] is False
        word = ws.receive_json()
        assert word["type"] == "word" and word["word"] == "hello"


def test_ws_jpeg_without_mediapipe_reports_error(client, user, monkeypatch):
    from app.routers import ws as ws_mod
    from app.services.landmarks import Unavailable

    def boom(_):
        raise Unavailable("Hand tracking needs: pip install mediapipe")

    monkeypatch.setattr(ws_mod.extractor, "from_jpeg", boom)
    with client.websocket_connect(f"/ws/sign?token={user['token']}") as ws:
        ws.receive_json()
        ws.send_bytes(b"x")
        assert "mediapipe" in ws.receive_json()["message"]
