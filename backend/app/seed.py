from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import Settings
from .models import SignWord, User
from .security import hash_password

# english, urdu, category  (same sample vocabulary as the app prototype)
DEFAULT_WORDS = [
    ("hello", "ہیلو", "greetings"), ("thank you", "شکریہ", "greetings"), ("yes", "ہاں", "basic"),
    ("no", "نہیں", "basic"), ("please", "براہ کرم", "greetings"), ("sorry", "معذرت", "greetings"),
    ("help", "مدد", "emergency"), ("water", "پانی", "daily"), ("food", "کھانا", "daily"),
    ("doctor", "ڈاکٹر", "health"), ("medicine", "دوا", "health"), ("pain", "درد", "health"),
    ("emergency", "ایمرجنسی", "emergency"), ("name", "نام", "basic"), ("good morning", "صبح بخیر", "greetings"),
    ("how are you", "آپ کیسے ہیں", "greetings"), ("where", "کہاں", "question"), ("money", "پیسے", "daily"),
    ("bank", "بینک", "places"), ("school", "سکول", "places"), ("friend", "دوست", "people"),
    ("family", "خاندان", "people"), ("wait", "انتظار کریں", "basic"), ("open", "کھولیں", "basic"),
    ("close", "بند کریں", "basic"), ("bus", "بس", "places"), ("train", "ٹرین", "places"),
    ("police", "پولیس", "emergency"), ("goodbye", "خدا حافظ", "greetings"), ("welcome", "خوش آمدید", "greetings"),
    ("love", "محبت", "feelings"), ("happy", "خوش", "feelings"), ("sad", "اداس", "feelings"), ("need", "چاہیے", "basic"),
]


def seed_all(db: Session, s: Settings) -> None:
    if db.scalar(select(SignWord.id).limit(1)) is None:
        db.add_all(SignWord(english_text=e, urdu_text=u, category=c) for e, u, c in DEFAULT_WORDS)
    if s.admin_email and s.admin_password:
        email = s.admin_email.lower()
        if db.scalar(select(User).where(User.email == email)) is None:
            db.add(User(full_name="Administrator", email=email, password_hash=hash_password(s.admin_password), role="admin"))
    db.commit()
