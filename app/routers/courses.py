from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.booking import Booking, BookingStatus
from app.models.course import Course
from app.models.member import Member
from app.routers.members import get_current_member, require_admin
from app.schemas.course_schema import CourseCreate, CourseOut, CourseUpdate
from app.schemas.member_schema import MemberOut

router = APIRouter(prefix="/courses", tags=["Courses"])


def _spots_available(course: Course, db: Session) -> int:
    booked = (
        db.query(Booking)
        .filter(
            Booking.course_id == course.id,
            Booking.status == BookingStatus.confirmed,
        )
        .count()
    )
    return max(0, course.max_capacity - booked)


def _enrich(course: Course, db: Session) -> CourseOut:
    out = CourseOut.model_validate(course)
    out.spots_available = _spots_available(course, db)

    coach = course.coach
    if coach is None and course.coach_id is not None:
        coach = db.query(Member).filter(Member.id == course.coach_id).first()

    if coach is not None:
        out.coach = MemberOut.model_validate(coach)
        out.coach_first_name = coach.first_name
        out.coach_last_name = coach.last_name
        out.coach_avatar_url = coach.avatar_url

    return out


@router.get("/", response_model=List[CourseOut])
def list_courses(
    from_date: Optional[datetime] = None,
    to_date: Optional[datetime] = None,
    course_type: Optional[str] = None,
    coach_id: Optional[int] = None,
    _current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    q = db.query(Course)
    if from_date:
        q = q.filter(Course.start_time >= from_date)
    if to_date:
        q = q.filter(Course.start_time <= to_date)
    if course_type:
        q = q.filter(Course.course_type == course_type)
    if coach_id:
        q = q.filter(Course.coach_id == coach_id)

    courses = q.order_by(Course.start_time).all()
    return [_enrich(course, db) for course in courses]


@router.get("/{course_id}", response_model=CourseOut)
def get_course(
    course_id: int,
    _current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    course = db.query(Course).filter(Course.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Cours introuvable")
    return _enrich(course, db)


@router.post("/", response_model=CourseOut, status_code=201)
def create_course(
    data: CourseCreate,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    course = Course(**data.model_dump())
    db.add(course)
    db.commit()
    db.refresh(course)
    return _enrich(course, db)


@router.put("/{course_id}", response_model=CourseOut)
def update_course(
    course_id: int,
    data: CourseUpdate,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    course = db.query(Course).filter(Course.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Cours introuvable")

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(course, field, value)

    db.commit()
    db.refresh(course)
    return _enrich(course, db)


@router.delete("/{course_id}", status_code=204)
def delete_course(
    course_id: int,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    course = db.query(Course).filter(Course.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Cours introuvable")

    # Important : supprimer d'abord les réservations associées, sinon la FK
    # bookings.course_id bloque la suppression du cours dans PostgreSQL.
    db.query(Booking).filter(Booking.course_id == course_id).delete(
        synchronize_session=False
    )
    db.delete(course)
    db.commit()
    return None
