from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.booking import Booking, BookingStatus
from app.models.course import Course
from app.models.member import Member, MemberRole
from app.routers.members import get_current_member, require_admin
from app.schemas.booking_schema import BookingCreate, BookingOut
from app.schemas.course_schema import CourseOut
from app.schemas.member_schema import MemberOut
from app.services import email_service, notification_service, waitlist_service

router = APIRouter(prefix="/bookings", tags=["Bookings"])


def _waitlist_position(booking: Booking, db: Session) -> int | None:
    """Rang du membre dans la liste d'attente du cours (1 = prochain promu)."""
    if booking.status != BookingStatus.waitlist:
        return None

    ahead = (
        db.query(Booking)
        .filter(
            Booking.course_id == booking.course_id,
            Booking.status == BookingStatus.waitlist,
            (Booking.booked_at < booking.booked_at)
            | ((Booking.booked_at == booking.booked_at) & (Booking.id < booking.id)),
        )
        .count()
    )
    return ahead + 1


def _confirmed_count(course_id: int, db: Session) -> int:
    return (
        db.query(Booking)
        .filter(
            Booking.course_id == course_id,
            Booking.status == BookingStatus.confirmed,
        )
        .count()
    )


def _spots_available(course: Course, db: Session) -> int:
    return max(0, course.max_capacity - _confirmed_count(course.id, db))


def _enrich_course(course: Course | None, db: Session) -> CourseOut | None:
    if course is None:
        return None

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


def _enrich_booking(booking: Booking, db: Session) -> BookingOut:
    out = BookingOut.model_validate(booking)
    out.course = _enrich_course(booking.course, db)
    out.waitlist_position = _waitlist_position(booking, db)
    return out


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _as_aware_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


@router.get("/me", response_model=List[BookingOut])
def my_bookings(
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    bookings = (
        db.query(Booking)
        .filter(Booking.member_id == current.id)
        .order_by(Booking.booked_at.desc())
        .all()
    )
    return [_enrich_booking(booking, db) for booking in bookings]


@router.post("/", response_model=BookingOut, status_code=201)
def create_booking(
    data: BookingCreate,
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    course = db.query(Course).filter(Course.id == data.course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Cours introuvable")

    if _as_aware_utc(course.start_time) < _now_utc():
        raise HTTPException(status_code=400, detail="Ce cours est déjà passé")

    existing = (
        db.query(Booking)
        .filter(
            Booking.member_id == current.id,
            Booking.course_id == data.course_id,
            Booking.status.in_([BookingStatus.confirmed, BookingStatus.waitlist]),
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Vous êtes déjà inscrit à ce cours")

    weekly_limit = getattr(current, "weekly_booking_limit", None)
    if weekly_limit is not None and weekly_limit > 0:
        start = _as_aware_utc(course.start_time)
        week_start = start - timedelta(days=start.weekday())
        week_start = week_start.replace(hour=0, minute=0, second=0, microsecond=0)
        week_end = week_start + timedelta(days=7)

        week_count = (
            db.query(Booking)
            .join(Course, Booking.course_id == Course.id)
            .filter(
                Booking.member_id == current.id,
                Booking.status == BookingStatus.confirmed,
                Course.start_time >= week_start,
                Course.start_time < week_end,
            )
            .count()
        )
        if week_count >= weekly_limit:
            raise HTTPException(
                status_code=400,
                detail=f"Limite hebdomadaire atteinte : {weekly_limit} cours par semaine",
            )

    status = (
        BookingStatus.confirmed
        if _confirmed_count(data.course_id, db) < course.max_capacity
        else BookingStatus.waitlist
    )

    booking = Booking(member_id=current.id, course_id=data.course_id, status=status)
    db.add(booking)
    db.commit()
    db.refresh(booking)

    if status == BookingStatus.waitlist:
        position = _waitlist_position(booking, db)
        notification_service.notify_waitlist_joined(db, current, course, position or 1)
    else:
        email_service.send_booking_confirmation(
            first_name=current.first_name,
            email=current.email,
            course_name=course.name,
            start_time=course.start_time.strftime("%d/%m/%Y à %H:%M"),
        )
    return _enrich_booking(booking, db)


@router.delete("/{booking_id}", response_model=BookingOut)
def cancel_booking(
    booking_id: int,
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    booking = (
        db.query(Booking)
        .filter(Booking.id == booking_id, Booking.member_id == current.id)
        .first()
    )
    if not booking:
        raise HTTPException(status_code=404, detail="Réservation introuvable")
    if booking.status == BookingStatus.cancelled:
        raise HTTPException(status_code=400, detail="Réservation déjà annulée")
    if booking.course and _as_aware_utc(booking.course.start_time) <= _now_utc():
        raise HTTPException(status_code=400, detail="Impossible d'annuler un cours déjà commencé")

    booking.status = BookingStatus.cancelled
    booking.cancelled_at = _now_utc()
    db.commit()

    email_service.send_booking_cancellation(
        first_name=current.first_name,
        email=current.email,
        course_name=booking.course.name,
    )

    # Une place s'est libérée → promeut le(s) premier(s) de la liste d'attente.
    if booking.course:
        waitlist_service.promote_waitlist(booking.course, db)

    db.refresh(booking)
    return _enrich_booking(booking, db)


@router.get("/course/{course_id}", response_model=List[BookingOut])
def course_bookings(
    course_id: int,
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    course = db.query(Course).filter(Course.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Cours introuvable")

    is_admin = current.role == MemberRole.admin
    is_assigned_coach = course.coach_id == current.id
    if not (is_admin or is_assigned_coach):
        raise HTTPException(status_code=403, detail="Accès réservé au coach du cours ou aux admins")

    bookings = (
        db.query(Booking)
        .filter(Booking.course_id == course_id)
        .order_by(Booking.booked_at)
        .all()
    )
    return [_enrich_booking(booking, db) for booking in bookings]
