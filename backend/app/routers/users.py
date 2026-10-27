from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import User
from ..schemas import UserOut, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user


@router.patch("/me", response_model=UserOut)
def update_me(body: UserUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if body.full_name is not None:
        user.full_name = body.full_name.strip()
    if body.preferred_language is not None:
        user.preferred_language = body.preferred_language
    if body.role is not None and user.role != "admin":
        user.role = body.role
    db.commit()
    db.refresh(user)
    return user
