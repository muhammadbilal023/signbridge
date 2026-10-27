"""Database tables - they match the ERD (diagram 18)."""
from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    full_name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(20), default="hearing")  # deaf_mute | hearing | admin
    preferred_language: Mapped[str] = mapped_column(String(10), default="en")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class SignWord(Base):
    __tablename__ = "sign_words"
    id: Mapped[int] = mapped_column(primary_key=True)
    english_text: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    urdu_text: Mapped[str] = mapped_column(String(80), default="")
    category: Mapped[str] = mapped_column(String(40), default="general")
    clips: Mapped[list["SignClip"]] = relationship(back_populates="word", cascade="all, delete-orphan")


class SignClip(Base):
    __tablename__ = "sign_clips"
    id: Mapped[int] = mapped_column(primary_key=True)
    word_id: Mapped[int] = mapped_column(ForeignKey("sign_words.id", ondelete="CASCADE"), index=True)
    file_path: Mapped[str] = mapped_column(String(255))
    duration_ms: Mapped[int] = mapped_column(Integer, default=0)
    source_language: Mapped[str] = mapped_column(String(10), default="PSL")  # PSL | ISL | own
    word: Mapped[SignWord] = relationship(back_populates="clips")


class LiveSession(Base):
    __tablename__ = "live_sessions"
    id: Mapped[int] = mapped_column(primary_key=True)
    session_code: Mapped[str] = mapped_column(String(12), unique=True, index=True)
    host_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    status: Mapped[str] = mapped_column(String(12), default="waiting")  # waiting | active | ended
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    participants: Mapped[list["SessionParticipant"]] = relationship(cascade="all, delete-orphan")


class SessionParticipant(Base):
    __tablename__ = "session_participants"
    session_id: Mapped[int] = mapped_column(ForeignKey("live_sessions.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), primary_key=True)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    left_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    user: Mapped[User] = relationship()


class Caption(Base):
    __tablename__ = "captions"
    id: Mapped[int] = mapped_column(primary_key=True)
    session_id: Mapped[int] = mapped_column(ForeignKey("live_sessions.id", ondelete="CASCADE"), index=True)
    speaker_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    text: Mapped[str] = mapped_column(Text)
    language: Mapped[str] = mapped_column(String(10), default="en")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id: Mapped[int] = mapped_column(primary_key=True)
    session_id: Mapped[int] = mapped_column(ForeignKey("live_sessions.id", ondelete="CASCADE"), index=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    body: Mapped[str] = mapped_column(Text)
    sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class EmotionLog(Base):
    __tablename__ = "emotion_logs"
    id: Mapped[int] = mapped_column(primary_key=True)
    session_id: Mapped[int] = mapped_column(ForeignKey("live_sessions.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    emotion_label: Mapped[str] = mapped_column(String(20))
    confidence: Mapped[float] = mapped_column(Float, default=0.0)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class TranslationHistory(Base):
    __tablename__ = "translation_history"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    mode: Mapped[str] = mapped_column(String(20))  # sign_to_text | text_to_sign
    input_text: Mapped[str] = mapped_column(Text)
    output_text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
