from datetime import datetime
from typing import Optional

from pydantic import BaseModel, model_validator

from app.models.course import CourseLevel, CourseType
from app.schemas.member_schema import MemberOut


class CourseCreate(BaseModel):
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
    name: Optional[str] = None
    description: Optional[str] = None
    course_type: Optional[CourseType] = None
    level: Optional[CourseLevel] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    max_capacity: Optional[int] = None
    coach_id: Optional[int] = None


class CourseOut(BaseModel):
    id: int
    name: str
    description: Optional[str]
    course_type: CourseType
    level: CourseLevel
    start_time: datetime
    end_time: datetime
    max_capacity: int
    coach_id: Optional[int]

    # Coach enrichi pour le front, notamment Mes cours / Détail cours.
    coach: Optional[MemberOut] = None
    coach_first_name: Optional[str] = None
    coach_last_name: Optional[str] = None
    coach_avatar_url: Optional[str] = None

    spots_available: Optional[int] = None
    created_at: datetime

    model_config = {"from_attributes": True}
