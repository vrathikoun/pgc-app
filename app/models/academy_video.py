from sqlalchemy import Column, Integer, String
from sqlalchemy.sql import func
from sqlalchemy import DateTime

from app.database import Base


class AcademyVideo(Base):
    __tablename__ = "academy_videos"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    section = Column(String, nullable=False)
    youtube_id = Column(String, nullable=False)
    description = Column(String, nullable=True)
    sort_order = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
