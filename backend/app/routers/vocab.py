import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from ..config import get_settings
from ..database import get_db
from ..deps import require_admin
from ..models import SignClip, SignWord
from ..schemas import WordIn, WordOut
from ..services.text_to_sign import clip_url

router = APIRouter(prefix="/vocabulary", tags=["vocabulary"])
ALLOWED = {"video/mp4": ".mp4", "video/webm": ".webm", "video/quicktime": ".mov"}


def _out(w: SignWord) -> WordOut:
    return WordOut(id=w.id, english_text=w.english_text, urdu_text=w.urdu_text, category=w.category,
                   clip_urls=[clip_url(c.file_path) for c in w.clips])


@router.get("", response_model=list[WordOut])
def list_words(q: str | None = None, category: str | None = None, db: Session = Depends(get_db)):
    stmt = select(SignWord).options(selectinload(SignWord.clips)).order_by(SignWord.english_text)
    if category:
        stmt = stmt.where(SignWord.category == category)
    if q:
        stmt = stmt.where(SignWord.english_text.ilike(f"%{q}%") | SignWord.urdu_text.contains(q))
    return [_out(w) for w in db.scalars(stmt)]


@router.post("", response_model=WordOut, status_code=201, dependencies=[Depends(require_admin)])
def add_word(body: WordIn, db: Session = Depends(get_db)):
    text = body.english_text.strip().lower()
    if db.scalar(select(SignWord.id).where(SignWord.english_text == text)):
        raise HTTPException(409, "Word already exists")
    w = SignWord(english_text=text, urdu_text=body.urdu_text.strip(), category=body.category)
    db.add(w)
    db.commit()
    db.refresh(w)
    return _out(w)


@router.post("/{word_id}/clips", response_model=WordOut, status_code=201, dependencies=[Depends(require_admin)])
async def upload_clip(word_id: int, file: UploadFile = File(...), source_language: str = Form("PSL"),
                      db: Session = Depends(get_db)):
    w = db.get(SignWord, word_id)
    if not w:
        raise HTTPException(404, "Word not found")
    ext = ALLOWED.get(file.content_type or "")
    if not ext:
        raise HTTPException(415, "Upload an mp4, webm or mov video")
    s = get_settings()
    limit, size = s.max_upload_mb * 1024 * 1024, 0
    folder = Path(s.media_dir) / "clips"
    folder.mkdir(parents=True, exist_ok=True)
    name = f"{word_id}_{uuid.uuid4().hex[:8]}{ext}"
    with open(folder / name, "wb") as out:
        while chunk := await file.read(1024 * 1024):
            size += len(chunk)
            if size > limit:
                out.close()
                (folder / name).unlink(missing_ok=True)
                raise HTTPException(413, f"File too large (max {s.max_upload_mb} MB)")
            out.write(chunk)
    db.add(SignClip(word_id=w.id, file_path=f"clips/{name}", source_language=source_language[:10]))
    db.commit()
    db.refresh(w)
    return _out(w)
