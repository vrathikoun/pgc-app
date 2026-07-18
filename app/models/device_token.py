from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base


class DeviceToken(Base):
    """Token FCM d'un appareil, pour envoyer des push à un membre.

    Un membre peut avoir plusieurs appareils (téléphone, tablette).
    Le token est unique : si le même appareil se reconnecte avec un autre
    compte, on réassigne simplement le token au nouveau membre.
    """

    __tablename__ = "device_tokens"

    id = Column(Integer, primary_key=True, index=True)
    member_id = Column(Integer, ForeignKey("members.id"), nullable=False, index=True)
    token = Column(String, unique=True, nullable=False, index=True)
    platform = Column(String, nullable=True)  # ios | android | web

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    member = relationship("Member")
