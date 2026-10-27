"""WebSocket endpoints for live sign recognition (diagram 9) and facial emotion (diagram 12).

/ws/sign?token=JWT&lang=en|ur
  client -> {"type":"landmarks","data":[126 floats],"t":ms?}  one message per camera frame (zeros = no hand)
         -> {"type":"finish"}  end the sentence now      -> {"type":"reset"}  forget current words
         -> binary JPEG frame  (server extracts landmarks; needs requirements-ml.txt)
  server -> ready | hands (landmarks for the overlay) | word | uncertain | sentence | error
/ws/emotion?token=JWT   client -> binary JPEG frame   server -> ready | emotion | error
"""
import json
import time

import numpy as np
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from fastapi.concurrency import run_in_threadpool

from ..config import get_settings
from ..security import decode_token
from ..services.emotion import Smoother, get_emotion_service
from ..services.features import FRAME_DIM, has_hand
from ..services.history import save_history
from ..services.landmarks import Unavailable, extractor
from ..services.recognizer import get_recognizer
from ..services.segmenter import Segmenter
from ..services.sentence import sentence_service

router = APIRouter(tags=["websockets"])


@router.websocket("/ws/sign")
async def ws_sign(ws: WebSocket, token: str = Query(""), lang: str = Query("en")):
    uid = decode_token(token)
    if uid is None:
        await ws.close(code=4401)
        return
    s, rec = get_settings(), get_recognizer()
    seg = Segmenter(s.word_gap_seconds, s.min_word_frames)
    words: list[str] = []
    await ws.accept()
    await ws.send_json({"type": "ready", "mode": rec.mode, "threshold": s.sign_threshold, "labels": len(rec.labels)})

    async def classify(segment):
        pred = await run_in_threadpool(rec.predict, segment)
        if pred.word == "none":
            return
        if pred.confidence >= s.sign_threshold:
            words.append(pred.word)
            await ws.send_json({"type": "word", "word": pred.word, "confidence": round(pred.confidence, 3), "index": len(words)})
        else:
            await ws.send_json({"type": "uncertain", "best": pred.word, "confidence": round(pred.confidence, 3)})

    async def finish():
        left = seg.flush()
        if left is not None:
            await classify(left)
        seg.reset_idle()
        if not words:
            await ws.send_json({"type": "sentence", "words": [], "sentence": "", "source": "fallback", "history_id": None})
            return
        sentence, source = await sentence_service.build(words, lang)
        hid = await run_in_threadpool(save_history, uid, "sign_to_text", " ".join(words), sentence)
        await ws.send_json({"type": "sentence", "words": list(words), "sentence": sentence, "source": source, "history_id": hid})
        words.clear()

    try:
        while True:
            msg = await ws.receive()
            if msg["type"] == "websocket.disconnect":
                break
            t = time.monotonic()
            if msg.get("text") is not None:
                try:
                    data = json.loads(msg["text"])
                except ValueError:
                    await ws.send_json({"type": "error", "message": "Invalid JSON"})
                    continue
                kind = data.get("type") if isinstance(data, dict) else None
                if kind == "finish":
                    await finish()
                    continue
                if kind == "reset":
                    words.clear()
                    seg.cur.clear()
                    seg.reset_idle()
                    continue
                arr = data.get("data") if kind == "landmarks" else None
                if not isinstance(arr, list) or len(arr) != FRAME_DIM:
                    await ws.send_json({"type": "error", "message": f'Send {{"type":"landmarks","data":[{FRAME_DIM} numbers]}}'})
                    continue
                vec = np.nan_to_num(np.asarray(arr, dtype=np.float32))
                if isinstance(data.get("t"), (int, float)):
                    t = data["t"] / 1000.0
            elif msg.get("bytes") is not None:
                try:
                    vec = await run_in_threadpool(extractor.from_jpeg, msg["bytes"])
                except (Unavailable, ValueError) as e:
                    await ws.send_json({"type": "error", "message": str(e)})
                    continue
                # let the app draw the hand skeleton on top of the camera preview
                await ws.send_json({"type": "hands", "present": has_hand(vec), "points": [round(float(v), 4) for v in vec]})
            else:
                continue
            segment, idle = seg.push(vec, t)
            if segment is not None:
                await classify(segment)
            if words and idle >= s.sentence_gap_seconds:
                await finish()
    except WebSocketDisconnect:
        pass


@router.websocket("/ws/emotion")
async def ws_emotion(ws: WebSocket, token: str = Query("")):
    if decode_token(token) is None:
        await ws.close(code=4401)
        return
    svc, smoother = get_emotion_service(), Smoother()
    await ws.accept()
    await ws.send_json({"type": "ready", "mode": svc.mode})
    try:
        while True:
            msg = await ws.receive()
            if msg["type"] == "websocket.disconnect":
                break
            if msg.get("bytes") is None:
                continue
            try:
                label, conf = await run_in_threadpool(svc.classify_jpeg, msg["bytes"])
            except (Unavailable, ValueError) as e:
                await ws.send_json({"type": "error", "message": str(e)})
                continue
            top, changed = smoother.push(label)
            await ws.send_json({"type": "emotion", "label": top, "confidence": round(conf, 3), "changed": changed, "mode": svc.mode})
    except WebSocketDisconnect:
        pass
