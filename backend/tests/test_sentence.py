import asyncio

from app.services.sentence import SentenceService


def _svc(monkeypatch, reply=None, error=False):
    monkeypatch.setattr(SentenceService, "configured", property(lambda self: True))
    s = SentenceService()
    s.calls = 0

    async def fake_post(payload):
        s.calls += 1
        if error:
            raise RuntimeError("network down")
        return {"choices": [{"message": {"content": reply}}]}

    s._post = fake_post
    return s


def test_fallback_when_not_configured(client, user):
    r = client.post("/sentence", json={"words": ["I", "water", "want"]}, headers=user["headers"])
    assert r.status_code == 200 and r.json()["sentence"] == "I water want" and r.json()["source"] == "fallback"
    assert client.get("/history", headers=user["headers"]).json()[0]["mode"] == "sign_to_text"


def test_llm_success(monkeypatch):
    s = _svc(monkeypatch, '```json\n{"sentence": "I want water."}\n```')
    assert asyncio.run(s.build(["I", "water", "want"])) == ("I want water.", "llm")


def test_llm_failures_fall_back(monkeypatch):
    for kw in ({"reply": "not json"}, {"reply": '{"sentence": "I want 500 rupees"}'}, {"error": True}):
        s = _svc(monkeypatch, **kw)
        assert asyncio.run(s.build(["I", "water", "want"])) == ("I water want", "fallback")


def test_single_word_does_not_call_llm(monkeypatch):
    s = _svc(monkeypatch, '{"sentence": "x"}')
    assert asyncio.run(s.build(["hello"])) == ("hello", "fallback") and s.calls == 0
