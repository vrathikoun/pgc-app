"""Enregistrement des tokens d'appareils (FCM) pour les push notifications."""
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.device_token import DeviceToken
from app.models.member import Member
from app.routers.members import get_current_member

router = APIRouter(prefix="/notifications", tags=["Notifications"])


class DeviceTokenIn(BaseModel):
    token: str
    platform: Optional[str] = None  # ios | android | web


@router.post("/device-token", status_code=204)
def register_device_token(
    data: DeviceTokenIn,
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    """Enregistre (ou réassigne) le token FCM de l'appareil au membre connecté."""
    existing = (
        db.query(DeviceToken).filter(DeviceToken.token == data.token).first()
    )
    if existing:
        # Le même appareil peut changer de compte : on réassigne le token.
        existing.member_id = current.id
        existing.platform = data.platform or existing.platform
    else:
        db.add(
            DeviceToken(
                member_id=current.id,
                token=data.token,
                platform=data.platform,
            )
        )
    db.commit()
    return None


@router.delete("/device-token", status_code=204)
def unregister_device_token(
    data: DeviceTokenIn,
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    """Supprime le token (à appeler à la déconnexion)."""
    db.query(DeviceToken).filter(
        DeviceToken.token == data.token,
        DeviceToken.member_id == current.id,
    ).delete(synchronize_session=False)
    db.commit()
    return None
