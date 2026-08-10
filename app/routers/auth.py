import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.member import Member
from app.models.password_reset import PasswordReset
from app.schemas.member_schema import (
    LoginRequest,
    MemberCreate,
    MemberOut,
    TokenOut,
    validate_password_72_bytes,
)
from app.core.security import create_access_token, hash_password, verify_password
from app.services import email_service

router = APIRouter(prefix="/auth", tags=["Auth"])

_RESET_CODE_TTL_MINUTES = 15


class ForgotPasswordIn(BaseModel):
    email: EmailStr


class ResetPasswordIn(BaseModel):
    email: EmailStr
    code: str
    new_password: str

    _validate_password = field_validator("new_password")(validate_password_72_bytes)


@router.post("/forgot-password", status_code=202)
def forgot_password(
    data: ForgotPasswordIn,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """Envoie un code de réinitialisation par email.

    Répond toujours 202, que l'email existe ou non (pas d'énumération de comptes).
    """
    member = db.query(Member).filter(Member.email == data.email).first()
    if member:
        # Invalide les codes précédents.
        db.query(PasswordReset).filter(
            PasswordReset.member_id == member.id,
            PasswordReset.used_at.is_(None),
        ).delete(synchronize_session=False)

        code = f"{secrets.randbelow(1_000_000):06d}"
        db.add(
            PasswordReset(
                member_id=member.id,
                code=code,
                expires_at=datetime.now(timezone.utc)
                + timedelta(minutes=_RESET_CODE_TTL_MINUTES),
            )
        )
        db.commit()
        background_tasks.add_task(
            email_service.send_password_reset, member.first_name, member.email, code
        )
    return {"message": "Si un compte existe, un code a été envoyé par email"}


@router.post("/reset-password")
def reset_password(data: ResetPasswordIn, db: Session = Depends(get_db)):
    """Réinitialise le mot de passe avec le code reçu par email."""
    member = db.query(Member).filter(Member.email == data.email).first()
    if not member:
        raise HTTPException(status_code=400, detail="Code invalide ou expiré")

    now = datetime.now(timezone.utc)
    reset = (
        db.query(PasswordReset)
        .filter(
            PasswordReset.member_id == member.id,
            PasswordReset.code == data.code.strip(),
            PasswordReset.used_at.is_(None),
        )
        .order_by(PasswordReset.created_at.desc())
        .first()
    )
    expires = reset.expires_at if reset else None
    if expires is not None and expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if not reset or not expires or expires < now:
        raise HTTPException(status_code=400, detail="Code invalide ou expiré")

    member.hashed_password = hash_password(data.new_password)
    reset.used_at = now
    db.commit()
    return {"message": "Mot de passe mis à jour, tu peux te connecter"}


@router.post("/register", response_model=MemberOut, status_code=201)
def register(
    data: MemberCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """Inscription d'un nouveau membre."""
    if db.query(Member).filter(Member.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email déjà utilisé")

    member = Member(
        email=data.email,
        hashed_password=hash_password(data.password),
        first_name=data.first_name,
        last_name=data.last_name,
        phone=data.phone,
        emergency_contact=data.emergency_contact,
    )
    db.add(member)
    db.commit()
    db.refresh(member)
    # E-mail de bienvenue envoyé en tâche de fond : un SMTP lent ou en échec ne
    # doit ni bloquer ni faire échouer l'inscription (le compte est déjà créé).
    background_tasks.add_task(email_service.send_welcome, member.first_name, member.email)
    return member


@router.post("/login", response_model=TokenOut)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    """Connexion — retourne un JWT."""
    member = db.query(Member).filter(Member.email == data.email).first()
    if not member or not verify_password(data.password, member.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect",
        )
    if not member.is_active:
        raise HTTPException(status_code=403, detail="Compte désactivé")

    token = create_access_token({"sub": str(member.id), "role": member.role})
    return {"access_token": token, "token_type": "bearer", "member": member}


@router.post("/token", include_in_schema=False)
def token_swagger(
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    """Endpoint OAuth2 utilisé uniquement par le bouton Authorize de Swagger.
    Le champ 'username' correspond à l'email."""
    member = db.query(Member).filter(Member.email == form.username).first()
    if not member or not verify_password(form.password, member.hashed_password):
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")
    if not member.is_active:
        raise HTTPException(status_code=403, detail="Compte désactivé")
    return {
        "access_token": create_access_token({"sub": str(member.id), "role": member.role}),
        "token_type": "bearer",
    }