import base64
import uuid
from pathlib import Path
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database import get_db
from app.models.member import Member, MemberRole
from app.schemas.member_schema import AvatarUpdate, MemberAdminRoleUpdate, MemberOut, MemberUpdate

UPLOAD_DIR = Path("uploads/avatars")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

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


@router.get("/coaches", response_model=List[MemberOut])
def list_coaches(
    _current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    """Liste des coachs et admins — accessible à tous les membres connectés."""
    return (
        db.query(Member)
        .filter(
            Member.role.in_([MemberRole.coach, MemberRole.admin]),
            Member.is_active == True,
        )
        .order_by(Member.first_name)
        .all()
    )




@router.get("/coaches/{coach_id}", response_model=MemberOut)
def get_coach_profile(
    coach_id: int,
    _current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    """Profil public d'un coach/admin — accessible aux membres connectés."""
    coach = (
        db.query(Member)
        .filter(
            Member.id == coach_id,
            Member.role.in_([MemberRole.coach, MemberRole.admin]),
            Member.is_active == True,
        )
        .first()
    )
    if not coach:
        raise HTTPException(status_code=404, detail="Coach introuvable")
    return coach


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


@router.post("/me/avatar", response_model=MemberOut)
def upload_my_avatar(
    data: AvatarUpdate,
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    """
    Upload avatar en base64. Le client envoie { "image_b64": "data:image/jpeg;base64,..." }
    On sauvegarde le fichier localement et on stocke l'URL dans avatar_url.
    """
    try:
        # Séparer le header data:image/jpeg;base64, du contenu
        header, encoded = data.image_b64.split(",", 1)
        ext = header.split("/")[1].split(";")[0]  # jpeg, png, webp
        if ext not in ("jpeg", "jpg", "png", "webp"):
            raise ValueError("Format non supporté")

        filename = f"{uuid.uuid4().hex}.{ext}"
        filepath = UPLOAD_DIR / filename
        filepath.write_bytes(base64.b64decode(encoded))

        current.avatar_url = f"/uploads/avatars/{filename}"
        db.commit()
        db.refresh(current)
        return current
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Upload invalide : {e}")


@router.post("/{member_id}/avatar", response_model=MemberOut)
def upload_member_avatar(
    member_id: int,
    data: AvatarUpdate,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Admin peut changer l'avatar de n'importe quel membre."""
    member = db.query(Member).filter(Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    try:
        header, encoded = data.image_b64.split(",", 1)
        ext = header.split("/")[1].split(";")[0]
        if ext not in ("jpeg", "jpg", "png", "webp"):
            raise ValueError("Format non supporté")
        filename = f"{uuid.uuid4().hex}.{ext}"
        filepath = UPLOAD_DIR / filename
        filepath.write_bytes(base64.b64decode(encoded))
        member.avatar_url = f"/uploads/avatars/{filename}"
        db.commit()
        db.refresh(member)
        return member
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Upload invalide : {e}")


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


@router.put("/{member_id}", response_model=MemberOut)
def update_member(
    member_id: int,
    data: MemberUpdate,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Admin peut modifier le profil complet d'un membre."""
    member = db.query(Member).filter(Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(member, field, value)
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