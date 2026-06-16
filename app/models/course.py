from sqlalchemy import Column, DateTime, Enum, ForeignKey, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum

from app.database import Base


class CourseType(str, enum.Enum):
    mma = "mma"
    grappling = "grappling"
    wrestling = "wrestling"
    other = "other"


class CourseLevel(str, enum.Enum):
    beginner = "beginner"
    intermediate = "intermediate"
    advanced = "advanced"
    all_levels = "all_levels"


class Course(Base):
    __tablename__ = "courses"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)

    # Type & niveau
    course_type = Column(Enum(CourseType), default=CourseType.other)
    level = Column(Enum(CourseLevel), default=CourseLevel.all_levels)

    # Planning
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=False)

    # Capacité
    max_capacity = Column(Integer, default=20)

    # Coach assigné
    coach_id = Column(Integer, ForeignKey("members.id"), nullable=True)
    coach = relationship("Member", foreign_keys=[coach_id])

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Rappel 24h : horodatage de l'envoi du rappel pour ce cours (évite les doublons).
    reminder_sent_at = Column(DateTime(timezone=True), nullable=True)

    # Relations
    bookings = relationship("Booking", back_populates="course")
