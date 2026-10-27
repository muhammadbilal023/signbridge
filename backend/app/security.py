from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from .config import get_settings


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode()[:72], bcrypt.gensalt()).decode()


def verify_password(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode()[:72], hashed.encode())
    except ValueError:
        return False


def create_access_token(user_id: int) -> str:
    s = get_settings()
    exp = datetime.now(timezone.utc) + timedelta(minutes=s.access_token_minutes)
    return jwt.encode({"sub": str(user_id), "exp": exp}, s.secret_key, algorithm="HS256")


def decode_token(token: str | None) -> int | None:
    if not token:
        return None
    try:
        data = jwt.decode(token, get_settings().secret_key, algorithms=["HS256"])
        return int(data["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
