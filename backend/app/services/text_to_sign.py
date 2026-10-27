"""Text -> playlist of sign clips. Longest phrase first ("how are you" before "how")."""
import re

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from ..models import SignWord

MAX_PHRASE = 4


def tokenize(text: str) -> list[str]:
    return [t for t in re.sub(r"[^\w\s]", " ", text.lower(), flags=re.UNICODE).split() if t]


def clip_url(path: str) -> str:
    return "/media/" + path.lstrip("/")


def map_text(db: Session, text: str) -> list[dict]:
    words = db.scalars(select(SignWord).options(selectinload(SignWord.clips))).all()
    index: dict[str, SignWord] = {}
    for w in words:
        index[w.english_text.lower()] = w
        if w.urdu_text:
            index[" ".join(tokenize(w.urdu_text))] = w
    tokens, out, i = tokenize(text), [], 0
    while i < len(tokens):
        for n in range(min(MAX_PHRASE, len(tokens) - i), 0, -1):
            phrase = " ".join(tokens[i:i + n])
            if phrase in index:
                w = index[phrase]
                url = clip_url(w.clips[0].file_path) if w.clips else None
                out.append({"word": phrase, "known": True, "clip_url": url})
                i += n
                break
        else:
            out.append({"word": tokens[i], "known": False, "clip_url": None})
            i += 1
    return out
