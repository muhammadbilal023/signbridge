from ..database import SessionLocal
from ..models import TranslationHistory


def save_history(user_id: int, mode: str, input_text: str, output_text: str, db=None) -> int:
    """Stores one translation. Opens its own DB session when none is given (used from websockets)."""
    if db is not None:
        row = TranslationHistory(user_id=user_id, mode=mode, input_text=input_text, output_text=output_text)
        db.add(row)
        db.commit()
        return row.id
    with SessionLocal() as own:
        return save_history(user_id, mode, input_text, output_text, own)
