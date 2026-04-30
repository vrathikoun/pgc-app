from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.models.booking import BookingStatus
from app.schemas.course_schema import CourseOut


class BookingCreate(BaseModel):
    """Données reçues pour créer une réservation."""
    course_id: int


class BookingOut(BaseModel):
    """Données retournées par l'API pour une réservation."""
    id: int
    member_id: int
    course_id: int
    status: BookingStatus
    notes: Optional[str]
    booked_at: datetime
    cancelled_at: Optional[datetime]
    course: Optional[CourseOut] = None  # relation chargée si besoin

    model_config = {"from_attributes": True}
