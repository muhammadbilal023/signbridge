import secrets
import string

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import LiveSession, SessionParticipant, User, utcnow
from ..schemas import ParticipantOut, SessionOut


def normalize_code(code: str) -> str:
    return code.strip().upper()


def generate_code(db: Session) -> str:
    for _ in range(50):
        code = "SB-" + "".join(secrets.choice(string.digits) for _ in range(6))
        if db.scalar(select(LiveSession.id).where(LiveSession.session_code == code)) is None:
            return code
    raise HTTPException(503, "Could not create a session code, try again")


def get_by_code(db: Session, code: str) -> LiveSession | None:
    return db.scalar(select(LiveSession).where(LiveSession.session_code == normalize_code(code)))


def get_member_session(db: Session, code: str, user: User) -> LiveSession:
    s = get_by_code(db, code)
    if not s:
        raise HTTPException(404, "Session not found")
    if db.get(SessionParticipant, (s.id, user.id)) is None:
        raise HTTPException(403, "You are not part of this session")
    return s


def to_out(db: Session, s: LiveSession) -> SessionOut:
    parts = [ParticipantOut(user_id=p.user_id, full_name=p.user.full_name, role=p.user.role) for p in s.participants]
    return SessionOut(code=s.session_code, status=s.status, host_id=s.host_id, participants=parts,
                      started_at=s.started_at, ended_at=s.ended_at)


def create_session(db: Session, host: User) -> LiveSession:
    s = LiveSession(session_code=generate_code(db), host_id=host.id, status="waiting")
    s.participants.append(SessionParticipant(user_id=host.id))
    db.add(s)
    db.commit()
    db.refresh(s)
    return s


def join_session(db: Session, code: str, user: User) -> LiveSession:
    s = get_by_code(db, code)
    if not s or s.status == "ended":
        raise HTTPException(404, "Session not found or already ended")
    existing = db.get(SessionParticipant, (s.id, user.id))
    if existing:  # rejoin after a network drop
        existing.left_at = None
    elif len(s.participants) >= 2:
        raise HTTPException(409, "Session is full (one-to-one only)")
    else:
        s.participants.append(SessionParticipant(user_id=user.id))
        s.status = "active"
    db.commit()
    db.refresh(s)
    return s


def end_session(db: Session, s: LiveSession) -> None:
    s.status, s.ended_at = "ended", utcnow()
    db.commit()
