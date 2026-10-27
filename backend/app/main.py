import logging
from contextlib import asynccontextmanager
from pathlib import Path

import socketio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import get_settings
from .database import Base, SessionLocal, engine
from .realtime import sio
from .routers import auth, history, sessions, translate, users, vocab, ws
from .seed import seed_all
from .services.landmarks import extractor

settings = get_settings()
log = logging.getLogger("signbridge")
Path(settings.media_dir, "clips").mkdir(parents=True, exist_ok=True)


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.env == "prod" and settings.secret_key.startswith("change-me"):
        raise RuntimeError("Set a real SECRET_KEY before running with ENV=prod")
    Base.metadata.create_all(engine)  # for real deployments use Alembic migrations instead
    with SessionLocal() as db:
        seed_all(db, settings)
    if extractor.installed():  # fetch the hand-tracking model in the background so the first camera frame is fast
        import threading

        def _warm():
            try:
                extractor.ensure_model()
            except Exception as e:  # offline etc. - the websocket will report a clear error later
                log.warning("hand model not ready: %s", e)

        threading.Thread(target=_warm, daemon=True).start()
    yield


api = FastAPI(title="SignBridge API", version="1.0.0", lifespan=lifespan,
              description="Backend for SignBridge: auth, vocabulary, text-to-sign, sign recognition, sentence builder, live sessions.")
api.add_middleware(CORSMiddleware, allow_origins=settings.cors_list, allow_methods=["*"], allow_headers=["*"])
api.mount("/media", StaticFiles(directory=settings.media_dir), name="media")
for r in (auth.router, users.router, vocab.router, translate.router, history.router, sessions.router, ws.router):
    api.include_router(r)


@api.get("/health", tags=["meta"])
def health():
    return {"status": "ok"}


# Socket.IO lives at /socket.io ; everything else goes to FastAPI. Run:  uvicorn app.main:app
app = socketio.ASGIApp(sio, other_asgi_app=api, socketio_path="socket.io")
