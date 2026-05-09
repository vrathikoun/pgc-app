from sqlalchemy import Boolean, Column, DateTime, Enum, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum

from app.database import Base


class MemberRole(str, enum.Enum):
    member = "member"
    coach = "coach"
    admin = "admin"


class SubscriptionStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"
    trial = "trial"
    suspended = "suspended"


class BeltRank(str, enum.Enum):
    # BJJ / Grappling NoGi
    white = "white"
    blue = "blue"
    purple = "purple"
    brown = "brown"
    black = "black"


class SubscriptionPlan(str, enum.Enum):
    unlimited = "unlimited"
    two_per_week = "two_per_week"


class Member(Base):
    __tablename__ = "members"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)

    # Infos personnelles
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    avatar_url = Column(String, nullable=True)

    # Niveau
    belt_rank = Column(String, default="white", nullable=True)

    # Rôle & statut
    # None = illimité. Exemple: 2 = maximum 2 cours confirmés par semaine.
    weekly_booking_limit = Column(Integer, nullable=True)

    role = Column(Enum(MemberRole), default=MemberRole.member, nullable=False)
    is_active = Column(Boolean, default=True)
    subscription_status = Column(
        Enum(SubscriptionStatus), default=SubscriptionStatus.trial
    )
    subscription_plan = Column(
        Enum(SubscriptionPlan),
        default=SubscriptionPlan.unlimited,
        nullable=False,
    )

    # Stripe
    stripe_customer_id = Column(String, nullable=True)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relations
    bookings = relationship("Booking", back_populates="member")