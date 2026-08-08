"""Avatar d'un membre stocké directement en base (table séparée).

On isole les octets de l'image dans sa propre table pour ne pas alourdir les
requêtes courantes sur `members`. L'URL publique de l'avatar
(`member.avatar_url`) pointe vers `GET /members/{id}/avatar`.
"""
from sqlalchemy import Column, DateTime, ForeignKey, Integer, LargeBinary, String, func

from app.database import Base


class MemberAvatar(Base):
    __tablename__ = "member_avatars"

    member_id = Column(
        Integer, ForeignKey("members.id"), primary_key=True
    )
    data = Column(LargeBinary, nullable=False)
    content_type = Column(String, nullable=False, default="image/jpeg")
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
