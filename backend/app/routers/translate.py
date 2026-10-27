import io

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..deps import get_current_user
from ..models import User
from ..schemas import EmotionOut, SentenceIn, SentenceOut, SttOut, TextToSignIn, TextToSignOut, TtsIn
from ..services.emotion import get_emotion_service
from ..services.history import save_history
from ..services.landmarks import extractor
from ..services.landmarks import Unavailable
from ..services.recognizer import get_recognizer
from ..services.sentence import sentence_service
from ..services.stt import stt_service
from ..services.text_to_sign import map_text
from ..services.tts import tts_service

router = APIRouter(tags=["translate"])


@router.post("/text-to-sign", response_model=TextToSignOut)
def text_to_sign(body: TextToSignIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    playlist = map_text(db, body.text)
    known = [p["word"] for p in playlist if p["known"]]
    hid = save_history(user.id, "text_to_sign", body.text, ", ".join(known) or "(no known signs)", db)
    return TextToSignOut(playlist=playlist, clips_available=sum(1 for p in playlist if p["clip_url"]), history_id=hid)


@router.post("/sentence", response_model=SentenceOut)
async def sentence(body: SentenceIn, user: User = Depends(get_current_user)):
    text, source = await sentence_service.build(body.words, body.language)
    hid = await run_in_threadpool(save_history, user.id, "sign_to_text", " ".join(body.words), text)
    return SentenceOut(sentence=text, source=source, history_id=hid)


@router.post("/stt", response_model=SttOut)
async def speech_to_text(file: UploadFile = File(...), language: str = Form("en"), user: User = Depends(get_current_user)):
    data = await file.read()
    if len(data) > get_settings().max_upload_mb * 1024 * 1024:
        raise HTTPException(413, "Audio too large")
    try:
        text = await run_in_threadpool(stt_service.transcribe, data, language if language in ("en", "ur") else None)
    except Unavailable as e:
        raise HTTPException(503, str(e))
    return SttOut(text=text)


@router.post("/tts", responses={200: {"content": {"audio/wav": {}}}})
async def text_to_speech(body: TtsIn, user: User = Depends(get_current_user)):
    try:
        audio = await run_in_threadpool(tts_service.synthesize, body.text, body.language)
    except Unavailable as e:
        raise HTTPException(503, str(e))
    return StreamingResponse(io.BytesIO(audio), media_type="audio/wav")


@router.post("/emotion", response_model=EmotionOut)
async def emotion(file: UploadFile = File(...), user: User = Depends(get_current_user)):
    svc = get_emotion_service()
    try:
        label, conf = await run_in_threadpool(svc.classify_jpeg, await file.read())
    except Unavailable as e:
        raise HTTPException(503, str(e))
    except ValueError as e:
        raise HTTPException(422, str(e))
    return EmotionOut(label=label, confidence=conf, mode=svc.mode)


@router.get("/recognition/status")
def recognition_status():
    r, s = get_recognizer(), get_settings()
    return {"mode": r.mode, "labels": r.labels, "threshold": s.sign_threshold,
            "emotion_mode": get_emotion_service().mode, "hand_tracking": extractor.status(), "llm_configured": sentence_service.configured,
            "stt_enabled": s.enable_stt, "tts_enabled": s.enable_tts}
