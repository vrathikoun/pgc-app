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

    # Rôle & statut
    role = Column(Enum(MemberRole), default=MemberRole.member, nullable=False)
    is_active = Column(Boolean, default=True)
    subscription_status = Column(
        Enum(SubscriptionStatus), default=SubscriptionStatus.trial
    )

    # Stripe
    stripe_customer_id = Column(String, nullable=True)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relations
    bookings = relationship("Booking", back_populates="member")
