from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.member import Member
from app.schemas.member import LoginRequest, MemberCreate, MemberOut, TokenOut
from app.core.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/register", response_model=MemberOut, status_code=201)
def register(data: MemberCreate, db: Session = Depends(get_db)):
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
