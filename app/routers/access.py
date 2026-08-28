"""Contrôle d'accès par QR code à l'accueil du club.

Principe :
- Le membre affiche dans l'app un QR contenant un jeton signé court (5 min),
  émis par `GET /access/my-qr`. Le jeton ne contient que l'id du membre + un
  scope dédié — pas d'info sensible, et il expire vite.
- L'accueil (staff coach/admin) scanne le QR et appelle `POST /access/verify`.
  Le statut d'abonnement est lu **en direct** en base (mis à jour par le
  webhook Stripe) : impossible de tricher avec une ancienne capture d'écran.
"""
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.security import create_access_token, decode_access_token
from app.core.timezone import PARIS, fmt_paris, now_paris
from app.database import get_db
from app.models.access_pass import AccessPass
from app.models.booking import Booking, BookingStatus
from app.models.course import Course
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


class TodayBookingOut(BaseModel):
    course_name: str
    time: str  # ex. "10:00" (heure de Paris)
    status: str  # confirmed | waitlist


class AccessVerifyOut(BaseModel):
    allowed: bool
    member_id: int
    first_name: str
    last_name: str
    subscription_status: str
    subscription_plan: str
    reason: str
    today_bookings: list[TodayBookingOut] = []


def _require_staff(current: Member = Depends(get_current_member)) -> Member:
    if current.role not in (MemberRole.admin, MemberRole.coach):
        raise HTTPException(status_code=403, detail="Réservé au staff du club")
    return current


def _check_and_consume_pass(member: Member, db: Session) -> tuple[bool, str]:
    """Autorise si le membre a un pass « cours à l'unité » valide, et le consomme.

    Les pass sont liés par email (achat possible avant création du compte).
    Un pass déjà consommé récemment (< 4 h) reste accepté pour tolérer un
    double scan à l'accueil sans re-décompter d'entrée.
    """
    now = datetime.now(timezone.utc)

    # Pass mensuel (multi-entrées, jamais consommé) : prioritaire.
    month = (
        db.query(AccessPass)
        .filter(
            AccessPass.email == member.email,
            AccessPass.pass_type.in_(("month_unlimited", "month_two_per_week")),
            AccessPass.expires_at > now,
        )
        .order_by(AccessPass.expires_at.desc())
        .first()
    )
    if month:
        label = (
            "illimité" if month.pass_type == "month_unlimited" else "2 cours/sem"
        )
        return True, f"Pass mensuel {label} — valable jusqu'au {month.expires_at:%d/%m}"

    pass_valide = (
        db.query(AccessPass)
        .filter(
            AccessPass.email == member.email,
            AccessPass.pass_type == "drop_in",
            AccessPass.consumed_at.is_(None),
            AccessPass.expires_at > now,
        )
        .order_by(AccessPass.expires_at.asc())
        .first()
    )
    if pass_valide:
        pass_valide.consumed_at = now
        if pass_valide.member_id is None:
            pass_valide.member_id = member.id
        db.commit()
        return True, "Cours à l'unité — pass validé"

    recent = (
        db.query(AccessPass)
        .filter(
            AccessPass.email == member.email,
            AccessPass.pass_type == "drop_in",
            AccessPass.consumed_at.isnot(None),
            AccessPass.consumed_at > now - timedelta(hours=4),
        )
        .first()
    )
    if recent:
        return True, "Cours à l'unité (déjà validé)"

    return False, ""


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
        # 1) Abonnement en cours payé (vérifié en direct chez Stripe).
        allowed, reason = stripe_service.check_member_access(member, db)
        # 2) Sinon, un pass « cours à l'unité » valide (consommé au scan).
        if not allowed:
            pass_ok, pass_reason = _check_and_consume_pass(member, db)
            if pass_ok:
                allowed, reason = True, pass_reason

    # Réservations du jour (heure de Paris) : permet à l'accueil de vérifier
    # que le membre assiste bien à un cours qu'il a réservé.
    day_start = now_paris().replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)
    today_rows = (
        db.query(Booking)
        .join(Course, Booking.course_id == Course.id)
        .filter(
            Booking.member_id == member.id,
            Booking.status.in_([BookingStatus.confirmed, BookingStatus.waitlist]),
            Course.start_time >= day_start.astimezone(PARIS),
            Course.start_time < day_end.astimezone(PARIS),
        )
        .order_by(Course.start_time)
        .all()
    )
    today_bookings = [
        TodayBookingOut(
            course_name=b.course.name if b.course else "Cours",
            time=fmt_paris(b.course.start_time, "%H:%M") if b.course else "",
            status=b.status.value if hasattr(b.status, "value") else str(b.status),
        )
        for b in today_rows
    ]

    return AccessVerifyOut(
        allowed=allowed,
        member_id=member.id,
        first_name=member.first_name,
        last_name=member.last_name,
        today_bookings=today_bookings,
        subscription_status=member.subscription_status.value
        if hasattr(member.subscription_status, "value")
        else str(member.subscription_status),
        subscription_plan=member.subscription_plan.value
        if hasattr(member.subscription_plan, "value")
        else str(member.subscription_plan or "aucun"),
        reason=reason,
    )
