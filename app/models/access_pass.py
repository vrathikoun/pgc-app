"""Pass d'accès à l'unité (cours payé à l'unité, hors abonnement).

Un paiement Stripe unique crée un pass valable quelques jours et à usage
unique : il est « consommé » au premier scan validé à l'accueil. Le lien avec
le membre se fait par email (le paiement peut précéder la création du compte).
"""
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func

from app.database import Base


class AccessPass(Base):
    __tablename__ = "access_passes"

    id = Column(Integer, primary_key=True, index=True)
    # Lien par email : le pass peut être acheté avant la création du compte.
    email = Column(String, index=True, nullable=False)
    member_id = Column(Integer, ForeignKey("members.id"), nullable=True)

    expires_at = Column(DateTime(timezone=True), nullable=False)
    consumed_at = Column(DateTime(timezone=True), nullable=True)

    stripe_payment_id = Column(String, nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
