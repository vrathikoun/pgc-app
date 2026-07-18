from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import List

from app.core.timezone import fmt_paris
from app.database import get_db
from app.models.member import Member
from app.models.subscription import Subscription, SubscriptionState
from app.routers.members import get_current_member, require_admin
from app.schemas.subscription_schema import SubscriptionCreate, SubscriptionOut
from app.services import stripe_service, email_service

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions"])


# ── Mon abonnement ────────────────────────────────────────────────────────────

@router.get("/me", response_model=List[SubscriptionOut])
def my_subscriptions(
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    """Historique des abonnements du membre connecté."""
    return (
        db.query(Subscription)
        .filter(Subscription.member_id == current.id)
        .order_by(Subscription.created_at.desc())
        .all()
    )


@router.post("/", response_model=SubscriptionOut, status_code=201)
def subscribe(
    data: SubscriptionCreate,
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    """Crée un abonnement Stripe pour le membre connecté."""
    # Vérifier qu'il n'a pas déjà un abonnement actif
    active = (
        db.query(Subscription)
        .filter(
            Subscription.member_id == current.id,
            Subscription.state == SubscriptionState.active,
        )
        .first()
    )
    if active:
        raise HTTPException(status_code=400, detail="Tu as déjà un abonnement actif")

    subscription = stripe_service.create_subscription(
        member=current,
        plan_type=data.plan_type,
        payment_method_id=data.payment_method_id,
        db=db,
    )

    # Email de confirmation
    if subscription.current_period_end:
        end_date = fmt_paris(subscription.current_period_end, "%d/%m/%Y")
    else:
        end_date = "–"

    email_service.send_subscription_confirmed(
        first_name=current.first_name,
        email=current.email,
        plan=data.plan_type.value,
        end_date=end_date,
    )

    return subscription


@router.delete("/me", response_model=SubscriptionOut)
def cancel_my_subscription(
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    """Annule l'abonnement actif en fin de période."""
    active = (
        db.query(Subscription)
        .filter(
            Subscription.member_id == current.id,
            Subscription.state == SubscriptionState.active,
        )
        .first()
    )
    if not active:
        raise HTTPException(status_code=404, detail="Aucun abonnement actif trouvé")

    return stripe_service.cancel_subscription(active, current, db)


# ── Webhook Stripe (pas d'auth JWT — appelé par Stripe directement) ───────────

@router.post("/webhook", include_in_schema=False)
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    """
    Endpoint appelé par Stripe pour notifier les changements d'abonnement.
    À enregistrer dans ton dashboard Stripe : https://dashboard.stripe.com/webhooks
    """
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature", "")

    result = stripe_service.handle_webhook(payload, sig_header, db)
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


# ── Admin : tous les abonnements ──────────────────────────────────────────────

@router.get("/", response_model=List[SubscriptionOut])
def list_subscriptions(
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return db.query(Subscription).order_by(Subscription.created_at.desc()).all()