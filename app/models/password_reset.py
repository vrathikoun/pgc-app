"""Codes de réinitialisation de mot de passe (envoyés par email).

Code à 6 chiffres, valable 15 minutes, à usage unique. Les anciens codes d'un
membre sont invalidés à chaque nouvelle demande.
"""
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func

from app.database import Base


class PasswordReset(Base):
    __tablename__ = "password_resets"

    id = Column(Integer, primary_key=True, index=True)
    member_id = Column(Integer, ForeignKey("members.id"), nullable=False, index=True)
    code = Column(String, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    used_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
