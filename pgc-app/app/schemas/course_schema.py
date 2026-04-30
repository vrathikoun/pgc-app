from datetime import datetime
from typing import Optional

from pydantic import BaseModel, model_validator

from app.models.course import CourseLevel, CourseType


class CourseCreate(BaseModel):
    """Données reçues pour créer un cours (admin uniquement)."""
    name: str
    description: Optional[str] = None
    course_type: CourseType = CourseType.other
    level: CourseLevel = CourseLevel.all_levels
    start_time: datetime
    end_time: datetime
    max_capacity: int = 20
    coach_id: Optional[int] = None

    @model_validator(mode="after")
    def end_after_start(self):
        if self.end_time <= self.start_time:
            raise ValueError("end_time doit être après start_time")
        return self


class CourseUpdate(BaseModel):
    """Champs modifiables d'un cours (admin uniquement)."""
    name: Optional[str] = None
    description: Optional[str] = None
    course_type: Optional[CourseType] = None
    level: Optional[CourseLevel] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    max_capacity: Optional[int] = None
    coach_id: Optional[int] = None


class CourseOut(BaseModel):
    """Données retournées par l'API pour un cours."""
    id: int
    name: str
    description: Optional[str]
    course_type: CourseType
    level: CourseLevel
    start_time: datetime
    end_time: datetime
    max_capacity: int
    coach_id: Optional[int]
    spots_available: Optional[int] = None  # calculé dynamiquement, pas en DB
    created_at: datetime

    model_config = {"from_attributes": True}
