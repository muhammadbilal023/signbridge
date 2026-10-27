import secrets

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..models import User
from ..schemas import FirebaseLoginIn, LoginIn, RegisterIn, TokenOut, UserOut
from ..security import create_access_token, hash_password, verify_password
from ..services.firebase_auth import FirebaseAuthError, verify_id_token

router = APIRouter(prefix="/auth", tags=["auth"])


def _token(user: User, is_new: bool = False) -> TokenOut:
    return TokenOut(access_token=create_access_token(user.id), user=UserOut.model_validate(user), is_new_user=is_new)


def _require_local():
    if not get_settings().local_auth_enabled:
        raise HTTPException(403, "Email/password accounts are handled by Firebase (with email verification). Use the app's Firebase sign-in.")


@router.get("/config")
def auth_config():
    s = get_settings()
    return {"firebase": bool(s.firebase_project_id), "local_auth": s.local_auth_enabled}


@router.post("/firebase", response_model=TokenOut)
def firebase_login(body: FirebaseLoginIn, db: Session = Depends(get_db)):
    """The app signs in with Firebase (Google or email+password), then sends the Firebase ID token here.
    Only VERIFIED emails are accepted, so nobody can register with someone else's address."""
    s = get_settings()
    if not s.firebase_project_id:
        raise HTTPException(503, "Firebase login is not configured on the server (set FIREBASE_PROJECT_ID)")
    try:
        claims = verify_id_token(body.id_token, s.firebase_project_id)
    except FirebaseAuthError:
        raise HTTPException(401, "Invalid or expired Firebase token")
    email = str(claims.get("email") or "").lower()
    if not email:
        raise HTTPException(401, "The Firebase account has no email address")
    if not claims.get("email_verified"):
        raise HTTPException(403, "Please verify your email first - open the link we sent to your inbox, then sign in again.")
    user = db.scalar(select(User).where(User.email == email))
    is_new = user is None
    if is_new:
        name = (body.full_name or claims.get("name") or email.split("@")[0]).strip()[:120] or "User"
        user = User(full_name=name, email=email, password_hash=hash_password(secrets.token_urlsafe(24)),
                    role=body.role or "hearing", preferred_language=body.preferred_language)
        db.add(user)
        db.commit()
        db.refresh(user)
    return _token(user, is_new)


@router.post("/register", response_model=TokenOut, status_code=201)
def register(body: RegisterIn, db: Session = Depends(get_db)):
    _require_local()
    email = body.email.lower()
    if db.scalar(select(User.id).where(User.email == email)):
        raise HTTPException(409, "Email already registered")
    user = User(full_name=body.full_name.strip(), email=email, password_hash=hash_password(body.password),
                role=body.role, preferred_language=body.preferred_language)
    db.add(user)
    db.commit()
    db.refresh(user)
    return _token(user)


def _authenticate(db: Session, email: str, password: str) -> User:
    user = db.scalar(select(User).where(User.email == email.lower()))
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(401, "Invalid email or password")
    return user


@router.post("/login", response_model=TokenOut)
def login(body: LoginIn, db: Session = Depends(get_db)):
    _require_local()
    return _token(_authenticate(db, body.email, body.password))


@router.post("/token", response_model=TokenOut, include_in_schema=False)
def token_form(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Form login (username = email) so the Swagger 'Authorize' button works."""
    _require_local()
    return _token(_authenticate(db, form.username, form.password))
