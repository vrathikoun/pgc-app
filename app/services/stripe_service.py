"""
Stripe Service — toute la logique Stripe est ici, les routers n'y touchent pas.

Plans configurés (à adapter selon tes tarifs) :
  monthly    → 49 €/mois
  quarterly  → 129 €/trimestre
  annual     → 449 €/an
"""
import time
from datetime import datetime, timedelta, timezone

import stripe
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.access_pass import AccessPass
from app.models.member import Member, SubscriptionPlan, SubscriptionStatus
from app.models.subscription import PlanType, Subscription, SubscriptionState
from app.services import email_service

stripe.api_key = settings.STRIPE_SECRET_KEY

# Statuts Stripe donnant droit à l'accès (abonnement en cours et payé).
_STRIPE_OK_STATUSES = {"active", "trialing"}


def _sub_field(sub, key):
    """Lit un champ d'un objet Subscription Stripe, tolérant dict ou StripeObject."""
    try:
        return sub[key]
    except Exception:
        return None


def _current_period_end(sub) -> int:
    """Fin de période courante, à la racine (API < 2025) ou au niveau des items."""
    end = _sub_field(sub, "current_period_end")
    if not end:
        try:
            items = sub["items"]["data"]
            end = items[0]["current_period_end"] if items else None
        except Exception:
            end = None
    return int(end) if end else 0


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
            else:
                # La recherche Stripe est sensible à la casse : rescanne en
                # comparant en minuscules (le client a pu saisir une majuscule
                # sur la page de paiement).
                # ponytail: scan complet des clients, OK jusqu'à quelques
                # milliers ; passer à Customer.search si le club grossit.
                target = (member.email or "").lower()
                for cu in stripe.Customer.list(limit=100).auto_paging_iter():
                    cu_email = _sub_field(cu, "email")
                    if (cu_email or "").lower() == target:
                        customer_id = cu["id"]
                        member.stripe_customer_id = customer_id
                        db.commit()
                        break

        if not customer_id:
            _sync_member_status(member, SubscriptionStatus.inactive, db)
            return False, "Aucun abonnement Stripe trouvé pour ce compte"

        subs = stripe.Subscription.list(customer=customer_id, status="all", limit=20)
        now = time.time()
        for s in subs.auto_paging_iter():
            status = _sub_field(s, "status")
            period_end = _current_period_end(s)
            if status in _STRIPE_OK_STATUSES and period_end > now:
                new_status = (
                    SubscriptionStatus.trial
                    if status == "trialing"
                    else SubscriptionStatus.active
                )
                _sync_member_status(member, new_status, db)
                # Synchronise le plan + la limite hebdo d'après le tarif Stripe
                # (fonctionne aussi pendant l'essai : le prix catalogue est connu).
                plan, limit = _plan_for_amount(_subscription_amount(s))
                if plan is not None and (
                    member.subscription_plan != plan
                    or member.weekly_booking_limit != limit
                ):
                    member.subscription_plan = plan
                    member.weekly_booking_limit = limit
                    db.commit()
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
        print("[WEBHOOK] Signature invalide (STRIPE_WEBHOOK_SECRET ne correspond pas)")
        return {"error": "Signature invalide"}

    event_type = event["type"]
    stripe_sub = event["data"]["object"]
    key_mode = "test" if settings.STRIPE_SECRET_KEY.startswith("sk_test") else "live"
    print(
        f"[WEBHOOK] type={event_type} livemode={event.get('livemode')} "
        f"cle_api={key_mode}"
    )

    if event_type in (
        "customer.subscription.created",
        "customer.subscription.updated",
        "customer.subscription.deleted",
    ):
        # Statut Stripe → statut membre.
        status = _sub_field(stripe_sub, "status")
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
            sub.current_period_start = _sub_field(stripe_sub, "current_period_start")
            sub.current_period_end = _current_period_end(stripe_sub) or None

        # Retrouve le membre : ligne locale, sinon customer Stripe, sinon email
        # (cas d'un abonnement souscrit via une page Stripe séparée).
        member = _member_for_subscription(stripe_sub, sub, db)
        if member:
            member.subscription_status = member_status
            # Règle le plan et la limite hebdo selon le tarif payé.
            if member_status == SubscriptionStatus.active:
                plan, limit = _plan_for_amount(_subscription_amount(stripe_sub))
                if plan is not None:
                    member.subscription_plan = plan
                    member.weekly_booking_limit = limit
        db.commit()

        # Nouvel abonnement : email de confirmation + lien pour créer/associer
        # le compte (même si l'abonnement est créé depuis le dashboard Stripe).
        if event_type == "customer.subscription.created":
            email = (
                member.email if member else _customer_email(stripe_sub.get("customer"))
            )
            print(
                f"[WEBHOOK] abonnement créé — membre={'oui' if member else 'non'} "
                f"email={email or 'INTROUVABLE'}"
            )
            if email:
                _safe_send_signup(email)

    # Paiement unique (cours à l'unité) via Checkout / lien de paiement.
    elif event_type == "checkout.session.completed":
        session = stripe_sub
        email = (session.get("customer_details") or {}).get("email") or session.get(
            "customer_email"
        )
        if email and session.get("mode") == "payment":
            created = _create_pass_for_payment(
                email,
                session.get("payment_intent") or session.get("id"),
                session.get("amount_total"),
                db,
            )
            if created is not None and created.pass_type == "drop_in":
                # Open mat / cours à l'unité : QR d'entrée par email, sans compte.
                _safe_send_open_mat_pass(created)
            elif created is not None:
                _safe_send_signup(email)

    return {"received": True, "type": event_type}


def _customer_email(customer_id):
    if not customer_id:
        return None
    try:
        return stripe.Customer.retrieve(customer_id).get("email")
    except Exception:
        return None


def _safe_send_signup(email: str) -> None:
    """Envoi de l'email post-paiement — un échec SMTP ne doit pas casser le webhook."""
    try:
        email_service.send_signup_after_payment(email)
        print(f"[WEBHOOK] email post-paiement envoyé à {email}")
    except Exception as exc:
        print(f"[WEBHOOK] email post-paiement NON envoyé à {email} : {type(exc).__name__}: {exc}")


def _subscription_amount(stripe_sub):
    """Montant (centimes) du 1er item de l'abonnement."""
    try:
        price = stripe_sub["items"]["data"][0]["price"]
        return price["unit_amount"]
    except Exception:
        return None


def _plan_for_amount(amount):
    """(plan, limite hebdo) selon le montant payé. (None, None) si inconnu."""
    if amount == settings.PRICE_TWO_PER_WEEK_CENTS:
        return SubscriptionPlan.two_per_week, 2
    if amount == settings.PRICE_UNLIMITED_CENTS:
        return SubscriptionPlan.unlimited, None
    return None, None


def _create_pass_for_payment(email: str, payment_id, amount_total, db: Session) -> None:
    """Crée le pass correspondant à un paiement unique (idempotent).

    150 € → pass mensuel illimité ; 100 € → pass mensuel 2 cours/semaine
    (30 jours glissants, multi-entrées) ; tout autre montant → pass à l'unité
    (7 jours, consommé au 1er scan).
    """
    if payment_id:
        exists = (
            db.query(AccessPass)
            .filter(AccessPass.stripe_payment_id == str(payment_id))
            .first()
        )
        if exists:
            return None

    if amount_total == settings.PRICE_MONTH_UNLIMITED_CENTS:
        pass_type, days = "month_unlimited", settings.MONTH_PASS_VALIDITY_DAYS
    elif amount_total == settings.PRICE_MONTH_TWO_PER_WEEK_CENTS:
        pass_type, days = "month_two_per_week", settings.MONTH_PASS_VALIDITY_DAYS
    else:
        pass_type, days = "drop_in", settings.DROP_IN_PASS_VALIDITY_DAYS

    member = db.query(Member).filter(Member.email == email).first()
    expires = datetime.now(timezone.utc) + timedelta(days=days)
    access_pass = AccessPass(
        email=email,
        member_id=member.id if member else None,
        expires_at=expires,
        pass_type=pass_type,
        stripe_payment_id=str(payment_id) if payment_id else None,
    )
    db.add(access_pass)
    db.commit()
    db.refresh(access_pass)
    print(f"[WEBHOOK] pass {pass_type} créé pour {email} (expire {expires:%d/%m})")
    return access_pass


def _safe_send_open_mat_pass(access_pass) -> None:
    """Email du QR invité — un échec SMTP ne doit pas casser le webhook."""
    try:
        from app.core.security import create_access_token

        remaining = access_pass.expires_at - datetime.now(timezone.utc)
        token = create_access_token(
            {"scope": "guest_pass", "pass": access_pass.id},
            expires_delta=remaining,
        )
        qr_url = f"{settings.PUBLIC_API_URL.rstrip('/')}/access/guest-qr/{token}"
        email_service.send_open_mat_pass(
            access_pass.email, qr_url, f"{access_pass.expires_at:%d/%m/%Y}"
        )
        print(f"[WEBHOOK] pass open mat envoyé à {access_pass.email}")
    except Exception as exc:
        print(f"[WEBHOOK] pass open mat NON envoyé : {type(exc).__name__}: {exc}")


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