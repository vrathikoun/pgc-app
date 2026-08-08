import base64
import io
import time
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Response
from fastapi.security import OAuth2PasswordBearer
from PIL import Image
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import decode_access_token
from app.database import get_db
from app.models.member import Member, MemberRole
from app.models.member_avatar import MemberAvatar
from app.schemas.member_schema import (
    AvatarUpdate,
    MemberAdminRoleUpdate,
    MemberOut,
    MemberUpdate,
)

router = APIRouter(prefix="/members", tags=["Members"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


def _store_avatar(member: Member, image_bytes: bytes, db: Session) -> None:
    """Compresse (256px, JPEG) et stocke l'avatar en base, puis met à jour l'URL.

    L'avatar est servi par GET /members/{id}/avatar. On ajoute un paramètre de
    version (?v=...) pour forcer le rafraîchissement du cache à chaque changement.
    """
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img.thumbnail((256, 256))
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=82)
    data = buf.getvalue()

    avatar = db.get(MemberAvatar, member.id)
    if avatar is None:
        avatar = MemberAvatar(member_id=member.id)
        db.add(avatar)
    avatar.data = data
    avatar.content_type = "image/jpeg"

    base = settings.PUBLIC_API_URL.rstrip("/")
    member.avatar_url = f"{base}/members/{member.id}/avatar?v={int(time.time())}"


def _decode_avatar_base64(image_b64: str) -> tuple[bytes, str]:
    """
    Accepte :
    - data:image/jpeg;base64,xxxxx
    - data:image/png;base64,xxxxx
    - data:image/webp;base64,xxxxx

    Retourne :
    - bytes de l'image
    - extension normalisée : jpg/png/webp
    """
    if "," not in image_b64:
        raise ValueError("Format base64 invalide")

    header, encoded = image_b64.split(",", 1)

    if not header.startswith("data:image/"):
        raise ValueError("Le fichier doit être une image")

    ext = header.split("/")[1].split(";")[0].lower()

    if ext == "jpeg":
        ext = "jpg"

    if ext not in ("jpg", "png", "webp"):
        raise ValueError("Format non supporté. Formats acceptés : jpg, png, webp")

    try:
        image_bytes = base64.b64decode(encoded)
    except Exception:
        raise ValueError("Impossible de décoder l'image")

    if not image_bytes:
        raise ValueError("Image vide")

    return image_bytes, ext


def get_current_member(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
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


@router.post("/me/avatar", response_model=MemberOut)
def upload_my_avatar(
    data: AvatarUpdate,
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    """Upload de l'avatar du membre connecté (stocké en base)."""
    try:
        image_bytes, _ext = _decode_avatar_base64(data.image_b64)
        _store_avatar(current, image_bytes, db)
        db.commit()
        db.refresh(current)
        return current
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Upload invalide : {e}")


@router.get("/{member_id}/avatar")
def get_member_avatar(member_id: int, db: Session = Depends(get_db)):
    """Sert l'image de l'avatar (public, mis en cache côté client)."""
    avatar = db.get(MemberAvatar, member_id)
    if avatar is None:
        raise HTTPException(status_code=404, detail="Pas d'avatar")
    return Response(
        content=avatar.data,
        media_type=avatar.content_type,
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.get("/coaches", response_model=List[MemberOut])
def list_coaches(
    _current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    # Carrousel « Coachs du moment » : uniquement le rôle coach (pas les admins).
    return (
        db.query(Member)
        .filter(
            Member.role == MemberRole.coach,
            Member.is_active == True,
        )
        .order_by(Member.first_name)
        .all()
    )


@router.get("/coaches/{coach_id}", response_model=MemberOut)
def get_coach_public(
    coach_id: int,
    _current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
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


@router.get("/", response_model=List[MemberOut])
def list_members(
    skip: int = 0,
    limit: int = 50,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(Member)
        .order_by(Member.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


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


@router.post("/{member_id}/avatar", response_model=MemberOut)
def upload_member_avatar(
    member_id: int,
    data: AvatarUpdate,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Upload de l'avatar d'un membre par un admin (stocké en base)."""
    member = db.query(Member).filter(Member.id == member_id).first()

    if not member:
        raise HTTPException(status_code=404, detail="Membre introuvable")

    try:
        image_bytes, _ext = _decode_avatar_base64(data.image_b64)
        _store_avatar(member, image_bytes, db)
        db.commit()
        db.refresh(member)
        return member
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Upload invalide : {e}")


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
    member = db.query(Member).filter(Member.id == member_id).first()

    if not member:
        raise HTTPException(status_code=404, detail="Membre introuvable")

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(member, field, value)

    db.commit()
    db.refresh(member)

    return member


@router.delete("/me", status_code=204)
def delete_my_account(
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    """Suppression définitive du compte et de toutes les données associées.

    Exigence App Store (Guideline 5.1.1(v)) : un membre doit pouvoir supprimer
    lui-même son compte depuis l'app. On supprime réellement les données (pas
    une simple désactivation) : réservations, jetons de notification,
    abonnements, puis le membre. Si le membre était coach d'un cours, on
    détache la référence pour ne pas casser le planning.
    """
    from app.models.booking import Booking
    from app.models.course import Course
    from app.models.device_token import DeviceToken
    from app.models.subscription import Subscription

    db.query(Booking).filter(Booking.member_id == current.id).delete(
        synchronize_session=False
    )
    db.query(DeviceToken).filter(DeviceToken.member_id == current.id).delete(
        synchronize_session=False
    )
    db.query(Subscription).filter(Subscription.member_id == current.id).delete(
        synchronize_session=False
    )
    db.query(Course).filter(Course.coach_id == current.id).update(
        {Course.coach_id: None}, synchronize_session=False
    )

    db.delete(current)
    db.commit()
    return None


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

    return None