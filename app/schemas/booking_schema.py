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

    # Position dans la liste d'attente (1 = prochain à être promu). null si non en attente.
    waitlist_position: Optional[int] = None

    model_config = {"from_attributes": True}
