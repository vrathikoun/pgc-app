"""Contrôle d'accès par QR code à l'accueil du club.

Principe :
- Le membre affiche dans l'app un QR contenant un jeton signé court (5 min),
  émis par `GET /access/my-qr`. Le jeton ne contient que l'id du membre + un
  scope dédié — pas d'info sensible, et il expire vite.
- L'accueil (staff coach/admin) scanne le QR et appelle `POST /access/verify`.
  Le statut d'abonnement est lu **en direct** en base (mis à jour par le
  webhook Stripe) : impossible de tricher avec une ancienne capture d'écran.
"""
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.security import create_access_token, decode_access_token
from app.database import get_db
from app.models.member import Member, MemberRole
from app.routers.members import get_current_member
from app.services import stripe_service

router = APIRouter(prefix="/access", tags=["Access"])

# Scope dédié : empêche d'utiliser un jeton d'authentification normal comme QR.
_QR_SCOPE = "access_check"
_QR_TTL_SECONDS = 300  # 5 minutes


class AccessQrOut(BaseModel):
    token: str
    expires_in: int


@router.get("/my-qr", response_model=AccessQrOut)
def my_access_qr(current: Member = Depends(get_current_member)):
    """Jeton signé à encoder dans le QR du membre (valable 5 min)."""
    token = create_access_token(
        {"sub": str(current.id), "scope": _QR_SCOPE},
        expires_delta=timedelta(seconds=_QR_TTL_SECONDS),
    )
    return AccessQrOut(token=token, expires_in=_QR_TTL_SECONDS)


class AccessVerifyIn(BaseModel):
    token: str


class AccessVerifyOut(BaseModel):
    allowed: bool
    member_id: int
    first_name: str
    last_name: str
    subscription_status: str
    subscription_plan: str
    reason: str


def _require_staff(current: Member = Depends(get_current_member)) -> Member:
    if current.role not in (MemberRole.admin, MemberRole.coach):
        raise HTTPException(status_code=403, detail="Réservé au staff du club")
    return current


@router.post("/verify", response_model=AccessVerifyOut)
def verify_access(
    data: AccessVerifyIn,
    _staff: Member = Depends(_require_staff),
    db: Session = Depends(get_db),
):
    """Vérifie un QR scanné à l'accueil et renvoie le droit d'accès en direct."""
    payload = decode_access_token(data.token)
    if not payload or payload.get("scope") != _QR_SCOPE or not payload.get("sub"):
        raise HTTPException(status_code=400, detail="QR code invalide ou expiré")

    member = db.query(Member).filter(Member.id == int(payload["sub"])).first()
    if not member:
        raise HTTPException(status_code=404, detail="Membre introuvable")

    if not member.is_active:
        allowed, reason = False, "Compte désactivé"
    else:
        # Vérification EN DIRECT auprès de Stripe (paiement de la période en
        # cours), avec repli sur le statut stocké si Stripe est injoignable.
        allowed, reason = stripe_service.check_member_access(member, db)

    return AccessVerifyOut(
        allowed=allowed,
        member_id=member.id,
        first_name=member.first_name,
        last_name=member.last_name,
        subscription_status=member.subscription_status.value
        if hasattr(member.subscription_status, "value")
        else str(member.subscription_status),
        subscription_plan=member.subscription_plan.value
        if hasattr(member.subscription_plan, "value")
        else str(member.subscription_plan),
        reason=reason,
    )
