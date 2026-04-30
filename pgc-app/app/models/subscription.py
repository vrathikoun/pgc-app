import enum

from sqlalchemy import Column, DateTime, Enum, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base


class PlanType(str, enum.Enum):
    monthly = "monthly"       # mensuel
    quarterly = "quarterly"   # trimestriel
    annual = "annual"         # annuel


class SubscriptionState(str, enum.Enum):
    active = "active"
    cancelled = "cancelled"
    past_due = "past_due"     # paiement en retard
    unpaid = "unpaid"


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True, index=True)

    member_id = Column(Integer, ForeignKey("members.id"), nullable=False)
    member = relationship("Member", backref="subscriptions")

    # Plan
    plan_type = Column(Enum(PlanType), nullable=False)
    price = Column(Numeric(10, 2), nullable=False)  # prix en euros

    # Statut
    state = Column(Enum(SubscriptionState), default=SubscriptionState.active)

    # Stripe
    stripe_subscription_id = Column(String, nullable=True, unique=True)
    stripe_price_id = Column(String, nullable=True)

    # Période en cours
    current_period_start = Column(DateTime(timezone=True), nullable=True)
    current_period_end = Column(DateTime(timezone=True), nullable=True)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    cancelled_at = Column(DateTime(timezone=True), nullable=True)