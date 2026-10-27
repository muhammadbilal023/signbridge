"""Socket.IO: WebRTC signaling + live captions, chat, emotion badge and sign translation relay (diagram 11)."""
import asyncio
import time

import socketio
from sqlalchemy import select

from .config import get_settings
from .database import SessionLocal
from .models import Caption, ChatMessage, EmotionLog, LiveSession, SessionParticipant
from .security import decode_token
from .services.landmarks import Unavailable
from .services.stt import stt_service

_s = get_settings()
sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins="*" if _s.cors_list == ["*"] else _s.cors_list)


async def run(fn, *args):
    def job():
        with SessionLocal() as db:
            return fn(db, *args)

    return await asyncio.to_thread(job)


# ---------- small DB helpers (each runs in a worker thread) ----------
def _join(db, code, uid):
    s = db.scalar(select(LiveSession).where(LiveSession.session_code == code))
    if not s or s.status == "ended":
        return None
    p = db.get(SessionParticipant, (s.id, uid))
    if not p:
        return None
    p.left_at = None
    db.commit()
    return s.id


def _caption(db, sid, uid, text, lang):
    c = Caption(session_id=sid, speaker_id=uid, text=text, language=lang)
    db.add(c)
    db.commit()
    return {"id": c.id, "speaker_id": uid, "text": text, "language": lang, "created_at": c.created_at.isoformat()}


def _chat(db, sid, uid, body):
    m = ChatMessage(session_id=sid, sender_id=uid, body=body)
    db.add(m)
    db.commit()
    return {"id": m.id, "sender_id": uid, "body": body, "sent_at": m.sent_at.isoformat()}


def _emotion(db, sid, uid, label, conf):
    db.add(EmotionLog(session_id=sid, user_id=uid, emotion_label=label, confidence=conf))
    db.commit()


def _end(db, code, uid):
    from .models import utcnow

    s = db.scalar(select(LiveSession).where(LiveSession.session_code == code))
    if not s or db.get(SessionParticipant, (s.id, uid)) is None:
        return False
    if s.status != "ended":
        s.status, s.ended_at = "ended", utcnow()
        db.commit()
    return True


async def notify_session_ended(code: str) -> None:
    await sio.emit("session_ended", {"code": code}, room=code)


# ---------- events ----------
@sio.event
async def connect(sid, environ, auth=None):
    token = auth.get("token") if isinstance(auth, dict) else None
    uid = decode_token(token)
    if uid is None:
        raise socketio.exceptions.ConnectionRefusedError("unauthorized")
    await sio.save_session(sid, {"user_id": uid, "code": None, "session_id": None, "emo": None, "emo_t": 0.0})


@sio.event
async def disconnect(sid):
    sess = await sio.get_session(sid)
    if sess.get("code"):
        await sio.emit("peer_left", {"user_id": sess["user_id"]}, room=sess["code"], skip_sid=sid)


async def _ctx(sid):
    sess = await sio.get_session(sid)
    return sess if sess.get("code") else None


@sio.on("join_room")
async def on_join_room(sid, data):
    code = str((data or {}).get("code", "")).strip().upper()
    sess = await sio.get_session(sid)
    session_id = await run(_join, code, sess["user_id"])
    if session_id is None:
        return {"ok": False, "error": "Not a participant of this session (join it with POST /sessions/join first)"}
    await sio.enter_room(sid, code)
    sess.update(code=code, session_id=session_id)
    await sio.save_session(sid, sess)
    await sio.emit("peer_joined", {"user_id": sess["user_id"]}, room=code, skip_sid=sid)
    return {"ok": True}


async def _relay(sid, event, data):
    sess = await _ctx(sid)
    if not sess:
        return {"ok": False, "error": "join_room first"}
    await sio.emit(event, data, room=sess["code"], skip_sid=sid)
    return {"ok": True}


@sio.on("offer")
async def on_offer(sid, data):
    return await _relay(sid, "offer", data)


@sio.on("answer")
async def on_answer(sid, data):
    return await _relay(sid, "answer", data)


@sio.on("ice_candidate")
async def on_ice(sid, data):
    return await _relay(sid, "ice_candidate", data)


async def _store_caption(sid, text, lang, event, to_others=False):
    sess = await _ctx(sid)
    text = str(text or "").strip()[:500]
    if not sess or not text:
        return {"ok": False, "error": "join_room first / empty text"}
    row = await run(_caption, sess["session_id"], sess["user_id"], text, lang)
    await sio.emit(event, row, room=sess["code"], skip_sid=sid if to_others else None)
    return {"ok": True, "caption": row}


@sio.on("caption")
async def on_caption(sid, data):
    return await _store_caption(sid, (data or {}).get("text"), (data or {}).get("language", "en"), "caption")


@sio.on("translated_text")
async def on_translated(sid, data):
    """Sign recognised on one side -> other side sees it as text (and it is saved as a caption)."""
    return await _store_caption(sid, (data or {}).get("text"), (data or {}).get("language", "en"), "translated_text", True)


@sio.on("audio_chunk")
async def on_audio(sid, data):
    sess = await _ctx(sid)
    if not sess:
        return {"ok": False, "error": "join_room first"}
    lang = (data or {}).get("language", "en")
    try:
        text = await asyncio.to_thread(stt_service.transcribe, (data or {}).get("audio") or b"", lang if lang in ("en", "ur") else None)
    except Unavailable as e:
        return {"ok": False, "error": str(e)}
    return await _store_caption(sid, text, lang, "caption") if text else {"ok": True, "caption": None}


@sio.on("chat_message")
async def on_chat(sid, data):
    sess = await _ctx(sid)
    body = str((data or {}).get("body", "")).strip()[:1000]
    if not sess or not body:
        return {"ok": False, "error": "join_room first / empty message"}
    row = await run(_chat, sess["session_id"], sess["user_id"], body)
    await sio.emit("chat_message", row, room=sess["code"])
    return {"ok": True}


@sio.on("emotion_update")
async def on_emotion(sid, data):
    sess = await _ctx(sid)
    label = str((data or {}).get("label", ""))[:20]
    if not sess or not label:
        return {"ok": False, "error": "join_room first / no label"}
    conf = float((data or {}).get("confidence", 0) or 0)
    now = time.monotonic()
    if label != sess["emo"] or now - sess["emo_t"] > 10:  # log only changes (or every 10 s)
        await run(_emotion, sess["session_id"], sess["user_id"], label, conf)
        sess.update(emo=label, emo_t=now)
        await sio.save_session(sid, sess)
    await sio.emit("emotion_update", {"user_id": sess["user_id"], "label": label, "confidence": conf}, room=sess["code"], skip_sid=sid)
    return {"ok": True}


@sio.on("end_session")
async def on_end(sid, data=None):
    sess = await _ctx(sid)
    if not sess:
        return {"ok": False, "error": "join_room first"}
    if not await run(_end, sess["code"], sess["user_id"]):
        return {"ok": False, "error": "not allowed"}
    await notify_session_ended(sess["code"])
    return {"ok": True}
