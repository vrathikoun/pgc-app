"""
Stripe Service — toute la logique Stripe est ici, les routers n'y touchent pas.

Plans configurés (à adapter selon tes tarifs) :
  monthly    → 49 €/mois
  quarterly  → 129 €/trimestre
  annual     → 449 €/an
"""
import time
from datetime import datetime, timezone

import stripe
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.member import Member, SubscriptionStatus
from app.models.subscription import PlanType, Subscription, SubscriptionState

stripe.api_key = settings.STRIPE_SECRET_KEY

# Statuts Stripe donnant droit à l'accès (abonnement en cours et payé).
_STRIPE_OK_STATUSES = {"active", "trialing"}


def _sync_member_status(member: Member, status: SubscriptionStatus, db: Session) -> None:
    if member.subscription_status != status:
        member.subscription_status = status
        db.commit()


def check_member_access(member: Member, db: Session) -> tuple[bool, str]:
    """Vérifie EN DIRECT auprès de Stripe si le membre a payé la période en cours.

    Retrouve le client Stripe (par stripe_customer_id ou, à défaut, par email —
    utile quand l'adhérent s'abonne via une page Stripe séparée) et cherche un
    abonnement `active`/`trialing` dont la période courante n'est pas expirée.
    Met à jour `member.subscription_status` au passage. En cas d'absence de
    configuration Stripe ou d'erreur réseau, retombe sur le statut stocké pour
    ne pas bloquer l'accueil.

    Retourne (accès autorisé, motif lisible).
    """
    if not settings.STRIPE_SECRET_KEY:
        return _fallback_from_stored(member)

    try:
        customer_id = member.stripe_customer_id
        if not customer_id:
            found = stripe.Customer.list(email=member.email, limit=1)
            if found.data:
                customer_id = found.data[0].id
                member.stripe_customer_id = customer_id
                db.commit()

        if not customer_id:
            _sync_member_status(member, SubscriptionStatus.inactive, db)
            return False, "Aucun abonnement Stripe trouvé pour ce compte"

        subs = stripe.Subscription.list(customer=customer_id, status="all", limit=20)
        now = time.time()
        for s in subs.auto_paging_iter():
            status = s.get("status")
            period_end = s.get("current_period_end") or 0
            if status in _STRIPE_OK_STATUSES and period_end > now:
                new_status = (
                    SubscriptionStatus.trial
                    if status == "trialing"
                    else SubscriptionStatus.active
                )
                _sync_member_status(member, new_status, db)
                end = datetime.fromtimestamp(period_end, tz=timezone.utc)
                label = "Période d'essai" if status == "trialing" else "Abonnement actif"
                return True, f"{label} jusqu'au {end:%d/%m/%Y}"

        _sync_member_status(member, SubscriptionStatus.inactive, db)
        return False, "Abonnement inactif ou paiement en attente"
    except Exception as exc:  # réseau/API Stripe indisponible → statut stocké
        allowed, reason = _fallback_from_stored(member)
        return allowed, f"{reason} (Stripe injoignable : {type(exc).__name__})"


def _fallback_from_stored(member: Member) -> tuple[bool, str]:
    ok = member.is_active and member.subscription_status in (
        SubscriptionStatus.active,
        SubscriptionStatus.trial,
    )
    labels = {
        SubscriptionStatus.active: "Abonnement actif",
        SubscriptionStatus.trial: "Période d'essai",
        SubscriptionStatus.inactive: "Abonnement inactif",
        SubscriptionStatus.suspended: "Abonnement suspendu",
    }
    return ok, labels.get(member.subscription_status, "Statut inconnu")

# ── Prix en centimes par plan (à adapter) ─────────────────────────────────────
PLAN_PRICES = {
    PlanType.monthly: {"amount": 4900, "interval": "month", "euros": 49.00},
    PlanType.quarterly: {"amount": 12900, "interval": "month", "interval_count": 3, "euros": 129.00},
    PlanType.annual: {"amount": 44900, "interval": "year", "euros": 449.00},
}


def get_or_create_stripe_customer(member: Member) -> str:
    """Retourne le stripe_customer_id existant ou en crée un nouveau."""
    if member.stripe_customer_id:
        return member.stripe_customer_id

    customer = stripe.Customer.create(
        email=member.email,
        name=f"{member.first_name} {member.last_name}",
        metadata={"member_id": member.id},
    )
    return customer.id


def create_subscription(
    member: Member, plan_type: PlanType, payment_method_id: str, db: Session
) -> Subscription:
    """Crée un abonnement Stripe et l'enregistre en base."""
    plan = PLAN_PRICES[plan_type]

    # 1. Créer ou récupérer le customer Stripe
    customer_id = get_or_create_stripe_customer(member)
    member.stripe_customer_id = customer_id

    # 2. Attacher le moyen de paiement au customer
    stripe.PaymentMethod.attach(payment_method_id, customer=customer_id)
    stripe.Customer.modify(
        customer_id,
        invoice_settings={"default_payment_method": payment_method_id},
    )

    # 3. Créer le prix à la volée (ou utilise des Price IDs fixes depuis ton dashboard)
    price = stripe.Price.create(
        unit_amount=plan["amount"],
        currency="eur",
        recurring={
            "interval": plan["interval"],
            **({"interval_count": plan["interval_count"]} if "interval_count" in plan else {}),
        },
        product_data={"name": f"Abonnement {plan_type.value}"},
    )

    # 4. Créer l'abonnement Stripe
    stripe_sub = stripe.Subscription.create(
        customer=customer_id,
        items=[{"price": price.id}],
        expand=["latest_invoice.payment_intent"],
    )

    # 5. Enregistrer en base
    subscription = Subscription(
        member_id=member.id,
        plan_type=plan_type,
        price=plan["euros"],
        state=SubscriptionState.active,
        stripe_subscription_id=stripe_sub.id,
        stripe_price_id=price.id,
        current_period_start=stripe_sub.current_period_start,
        current_period_end=stripe_sub.current_period_end,
    )
    member.subscription_status = SubscriptionStatus.active

    db.add(subscription)
    db.commit()
    db.refresh(subscription)
    return subscription


def cancel_subscription(subscription: Subscription, member: Member, db: Session) -> Subscription:
    """Annule l'abonnement en fin de période (pas de remboursement immédiat)."""
    if subscription.stripe_subscription_id:
        stripe.Subscription.modify(
            subscription.stripe_subscription_id,
            cancel_at_period_end=True,
        )

    subscription.state = SubscriptionState.cancelled
    member.subscription_status = SubscriptionStatus.inactive
    db.commit()
    db.refresh(subscription)
    return subscription


def handle_webhook(payload: bytes, sig_header: str, db: Session) -> dict:
    """
    Traite les événements Stripe (appelé par le router /subscriptions/webhook).
    Stripe envoie des événements asynchrones pour confirmer les paiements.
    """
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
        )
    except stripe.error.SignatureVerificationError:
        return {"error": "Signature invalide"}

    event_type = event["type"]
    stripe_sub = event["data"]["object"]

    if event_type in (
        "customer.subscription.created",
        "customer.subscription.updated",
        "customer.subscription.deleted",
    ):
        # Statut Stripe → statut membre.
        status = stripe_sub.get("status")
        member_status = (
            SubscriptionStatus.active
            if status in _STRIPE_OK_STATUSES
            else SubscriptionStatus.inactive
        )

        # Met à jour la ligne locale si elle existe (abonnement pris dans l'app).
        sub = (
            db.query(Subscription)
            .filter(Subscription.stripe_subscription_id == stripe_sub["id"])
            .first()
        )
        if sub:
            sub.state = (
                SubscriptionState.active
                if status == "active"
                else SubscriptionState.past_due
                if status == "past_due"
                else SubscriptionState.cancelled
            )
            sub.current_period_start = stripe_sub.get("current_period_start")
            sub.current_period_end = stripe_sub.get("current_period_end")

        # Retrouve le membre : ligne locale, sinon customer Stripe, sinon email
        # (cas d'un abonnement souscrit via une page Stripe séparée).
        member = _member_for_subscription(stripe_sub, sub, db)
        if member:
            member.subscription_status = member_status
        db.commit()

    return {"received": True, "type": event_type}


def _member_for_subscription(stripe_sub, sub, db: Session):
    """Retrouve le membre lié à un abonnement Stripe (matching robuste)."""
    if sub:
        return db.query(Member).filter(Member.id == sub.member_id).first()

    customer_id = stripe_sub.get("customer")
    if not customer_id:
        return None

    member = (
        db.query(Member).filter(Member.stripe_customer_id == customer_id).first()
    )
    if member:
        return member

    # Pas encore lié : on retrouve par email et on mémorise le customer id.
    try:
        customer = stripe.Customer.retrieve(customer_id)
        email = customer.get("email")
    except Exception:
        email = None
    if not email:
        return None

    member = db.query(Member).filter(Member.email == email).first()
    if member:
        member.stripe_customer_id = customer_id
    return member