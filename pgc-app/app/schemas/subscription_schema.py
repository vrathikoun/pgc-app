from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel

from app.models.subscription import PlanType, SubscriptionState


class SubscriptionCreate(BaseModel):
    """Données reçues pour créer un abonnement."""
    plan_type: PlanType
    # stripe_payment_method_id fourni par le SDK Stripe côté mobile
    payment_method_id: str


class SubscriptionOut(BaseModel):
    """Données retournées par l'API pour un abonnement."""
    id: int
    member_id: int
    plan_type: PlanType
    price: Decimal
    state: SubscriptionState
    current_period_start: Optional[datetime]
    current_period_end: Optional[datetime]
    created_at: datetime
    cancelled_at: Optional[datetime]
    # On n'expose jamais stripe_subscription_id ni stripe_price_id

    model_config = {"from_attributes": True}


class SubscriptionWebhookEvent(BaseModel):
    """Payload reçu depuis Stripe via webhook."""
    type: str        # ex: "customer.subscription.updated"
    data: dict