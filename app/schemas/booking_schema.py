from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.models.booking import BookingStatus
from app.schemas.course_schema import CourseOut


class BookingCreate(BaseModel):
    course_id: int


class BookingOut(BaseModel):
    id: int
    member_id: int
    course_id: int
    status: BookingStatus
    notes: Optional[str]
    booked_at: datetime
    cancelled_at: Optional[datetime]
    course: Optional[CourseOut] = None

    model_config = {"from_attributes": True}
