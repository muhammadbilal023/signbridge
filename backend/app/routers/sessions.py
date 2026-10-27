from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import Caption, ChatMessage, LiveSession, SessionParticipant, User
from ..realtime import notify_session_ended
from ..schemas import CaptionOut, ChatOut, JoinIn, SessionOut
from ..services import sessions as svc

router = APIRouter(prefix="/sessions", tags=["live sessions"])


@router.post("", response_model=SessionOut, status_code=201)
def create(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return svc.to_out(db, svc.create_session(db, user))


@router.post("/join", response_model=SessionOut)
def join(body: JoinIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return svc.to_out(db, svc.join_session(db, body.code, user))


@router.get("", response_model=list[SessionOut])
def mine(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    stmt = (select(LiveSession).join(SessionParticipant, SessionParticipant.session_id == LiveSession.id)
            .where(SessionParticipant.user_id == user.id).order_by(LiveSession.id.desc()).limit(50))
    return [svc.to_out(db, s) for s in db.scalars(stmt)]


@router.get("/{code}", response_model=SessionOut)
def detail(code: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return svc.to_out(db, svc.get_member_session(db, code, user))


@router.post("/{code}/end", response_model=SessionOut)
async def end(code: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    s = svc.get_member_session(db, code, user)
    if s.status != "ended":
        svc.end_session(db, s)
        await notify_session_ended(s.session_code)
    return svc.to_out(db, s)


@router.get("/{code}/captions", response_model=list[CaptionOut])
def captions(code: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    s = svc.get_member_session(db, code, user)
    return db.scalars(select(Caption).where(Caption.session_id == s.id).order_by(Caption.id)).all()


@router.get("/{code}/chat", response_model=list[ChatOut])
def chat(code: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    s = svc.get_member_session(db, code, user)
    return db.scalars(select(ChatMessage).where(ChatMessage.session_id == s.id).order_by(ChatMessage.id)).all()
