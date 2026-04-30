from datetime import datetime, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.booking import Booking, BookingStatus
from app.models.course import Course
from app.models.member import Member
from app.routers.members import get_current_member, require_admin
from app.schemas.booking import BookingCreate, BookingOut

router = APIRouter(prefix="/bookings", tags=["Bookings"])


def _confirmed_count(course_id: int, db: Session) -> int:
    return (
        db.query(Booking)
        .filter(
            Booking.course_id == course_id,
            Booking.status == BookingStatus.confirmed,
        )
        .count()
    )


# ── Mes réservations ──────────────────────────────────────────────────────────

@router.get("/me", response_model=List[BookingOut])
def my_bookings(
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    return (
        db.query(Booking)
        .filter(Booking.member_id == current.id)
        .order_by(Booking.booked_at.desc())
        .all()
    )


# ── Créer une réservation ─────────────────────────────────────────────────────

@router.post("/", response_model=BookingOut, status_code=201)
def create_booking(
    data: BookingCreate,
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    # Vérifier que le cours existe
    course = db.query(Course).filter(Course.id == data.course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Cours introuvable")

    # Cours déjà passé ?
    if course.start_time < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Ce cours est déjà passé")

    # Déjà réservé ?
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

    # Capacité disponible ou liste d'attente ?
    count = _confirmed_count(data.course_id, db)
    status = (
        BookingStatus.confirmed if count < course.max_capacity else BookingStatus.waitlist
    )

    booking = Booking(
        member_id=current.id,
        course_id=data.course_id,
        status=status,
    )
    db.add(booking)
    db.commit()
    db.refresh(booking)
    return booking


# ── Annuler une réservation ───────────────────────────────────────────────────

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

    booking.status = BookingStatus.cancelled
    booking.cancelled_at = datetime.now(timezone.utc)
    db.commit()

    # Promouvoir le premier en liste d'attente
    next_waiting = (
        db.query(Booking)
        .filter(
            Booking.course_id == booking.course_id,
            Booking.status == BookingStatus.waitlist,
        )
        .order_by(Booking.booked_at)
        .first()
    )
    if next_waiting:
        next_waiting.status = BookingStatus.confirmed
        db.commit()

    db.refresh(booking)
    return booking


# ── Admin : toutes les réservations d'un cours ───────────────────────────────

@router.get("/course/{course_id}", response_model=List[BookingOut])
def course_bookings(
    course_id: int,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(Booking)
        .filter(Booking.course_id == course_id)
        .order_by(Booking.booked_at)
        .all()
    )
