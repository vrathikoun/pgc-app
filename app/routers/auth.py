from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.member import Member
from app.schemas.member_schema import LoginRequest, MemberCreate, MemberOut, TokenOut
from app.core.security import create_access_token, hash_password, verify_password
from app.services import email_service

router = APIRouter(prefix="/auth", tags=["Auth"])


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