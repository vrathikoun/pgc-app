"""
Stripe Service — toute la logique Stripe est ici, les routers n'y touchent pas.

Plans configurés (à adapter selon tes tarifs) :
  monthly    → 49 €/mois
  quarterly  → 129 €/trimestre
  annual     → 449 €/an
"""
import stripe
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.member import Member, SubscriptionStatus
from app.models.subscription import PlanType, Subscription, SubscriptionState

stripe.api_key = settings.STRIPE_SECRET_KEY

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

    # Abonnement mis à jour (renouvellement, changement de statut)
    if event_type in ("customer.subscription.updated", "customer.subscription.deleted"):
        sub = (
            db.query(Subscription)
            .filter(Subscription.stripe_subscription_id == stripe_sub["id"])
            .first()
        )
        if sub:
            sub.state = (
                SubscriptionState.active
                if stripe_sub["status"] == "active"
                else SubscriptionState.past_due
                if stripe_sub["status"] == "past_due"
                else SubscriptionState.cancelled
            )
            sub.current_period_start = stripe_sub.get("current_period_start")
            sub.current_period_end = stripe_sub.get("current_period_end")

            # Synchroniser le statut sur le membre
            member = db.query(Member).filter(Member.id == sub.member_id).first()
            if member:
                member.subscription_status = (
                    SubscriptionStatus.active
                    if sub.state == SubscriptionState.active
                    else SubscriptionStatus.inactive
                )
            db.commit()

    return {"received": True, "type": event_type}