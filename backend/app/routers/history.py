from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import TranslationHistory, User
from ..schemas import HistoryOut

router = APIRouter(prefix="/history", tags=["history"])


@router.get("", response_model=list[HistoryOut])
def list_history(mode: str | None = None, limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
                 user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    stmt = select(TranslationHistory).where(TranslationHistory.user_id == user.id)
    if mode:
        stmt = stmt.where(TranslationHistory.mode == mode)
    return db.scalars(stmt.order_by(TranslationHistory.id.desc()).limit(limit).offset(offset)).all()


@router.delete("/{history_id}", status_code=204)
def delete_one(history_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    row = db.get(TranslationHistory, history_id)
    if not row or row.user_id != user.id:
        raise HTTPException(404, "Not found")
    db.delete(row)
    db.commit()


@router.delete("", status_code=204)
def clear_all(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.execute(delete(TranslationHistory).where(TranslationHistory.user_id == user.id))
    db.commit()
