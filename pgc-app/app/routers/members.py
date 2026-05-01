from typing import List

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database import get_db
from app.models.member import Member, MemberRole
from app.schemas.member_schema import MemberAdminRoleUpdate, MemberOut, MemberUpdate

router = APIRouter(prefix="/members", tags=["Members"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


def get_current_member(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> Member:
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token invalide ou expiré")
    member = db.query(Member).filter(Member.id == int(payload["sub"])).first()
    if not member or not member.is_active:
        raise HTTPException(status_code=401, detail="Membre introuvable")
    return member


def require_admin(current: Member = Depends(get_current_member)) -> Member:
    if current.role != MemberRole.admin:
        raise HTTPException(status_code=403, detail="Accès réservé aux admins")
    return current


@router.get("/me", response_model=MemberOut)
def get_me(current: Member = Depends(get_current_member)):
    return current


@router.put("/me", response_model=MemberOut)
def update_me(
    data: MemberUpdate,
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(current, field, value)
    db.commit()
    db.refresh(current)
    return current


@router.get("/", response_model=List[MemberOut])
def list_members(
    skip: int = 0,
    limit: int = 50,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return db.query(Member).order_by(Member.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{member_id}", response_model=MemberOut)
def get_member(
    member_id: int,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    member = db.query(Member).filter(Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    return member


@router.patch("/{member_id}/role", response_model=MemberOut)
def update_member_role(
    member_id: int,
    data: MemberAdminRoleUpdate,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    member = db.query(Member).filter(Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    member.role = data.role
    db.commit()
    db.refresh(member)
    return member


@router.delete("/{member_id}", status_code=204)
def deactivate_member(
    member_id: int,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    member = db.query(Member).filter(Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    member.is_active = False
    db.commit()
