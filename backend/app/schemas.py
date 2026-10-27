from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class UserOut(ORM):
    id: int
    full_name: str
    email: EmailStr
    role: str
    preferred_language: str
    created_at: datetime


class RegisterIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)
    role: Literal["deaf_mute", "hearing"] = "hearing"
    preferred_language: Literal["en", "ur"] = "en"


class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(max_length=72)


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
    is_new_user: bool = False


class FirebaseLoginIn(BaseModel):
    id_token: str = Field(min_length=20)
    role: Literal["deaf_mute", "hearing"] | None = None
    full_name: str | None = Field(default=None, max_length=120)
    preferred_language: Literal["en", "ur"] = "en"


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    preferred_language: Literal["en", "ur"] | None = None
    role: Literal["deaf_mute", "hearing"] | None = None


class WordIn(BaseModel):
    english_text: str = Field(min_length=1, max_length=80)
    urdu_text: str = Field(default="", max_length=80)
    category: str = Field(default="general", max_length=40)


class WordOut(BaseModel):
    id: int
    english_text: str
    urdu_text: str
    category: str
    clip_urls: list[str]


class TextToSignIn(BaseModel):
    text: str = Field(min_length=1, max_length=500)


class PlaylistItem(BaseModel):
    word: str
    known: bool
    clip_url: str | None


class TextToSignOut(BaseModel):
    playlist: list[PlaylistItem]
    clips_available: int
    history_id: int


class SentenceIn(BaseModel):
    words: list[str] = Field(min_length=1, max_length=30)
    language: Literal["en", "ur"] = "en"


class SentenceOut(BaseModel):
    sentence: str
    source: Literal["llm", "fallback"]
    history_id: int


class TtsIn(BaseModel):
    text: str = Field(min_length=1, max_length=400)
    language: Literal["en", "ur"] = "ur"


class SttOut(BaseModel):
    text: str


class EmotionOut(BaseModel):
    label: str | None
    confidence: float
    mode: str


class ParticipantOut(BaseModel):
    user_id: int
    full_name: str
    role: str


class SessionOut(BaseModel):
    code: str
    status: str
    host_id: int
    participants: list[ParticipantOut]
    started_at: datetime
    ended_at: datetime | None


class JoinIn(BaseModel):
    code: str = Field(min_length=3, max_length=12)


class CaptionOut(ORM):
    id: int
    speaker_id: int
    text: str
    language: str
    created_at: datetime


class ChatOut(ORM):
    id: int
    sender_id: int
    body: str
    sent_at: datetime


class HistoryOut(ORM):
    id: int
    mode: str
    input_text: str
    output_text: str
    created_at: datetime
