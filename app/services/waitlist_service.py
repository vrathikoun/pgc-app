"""
Waitlist Service — promotion automatique depuis la liste d'attente.

Promeut autant de membres en attente qu'il y a de places libres sur le cours
(1 place libérée → 1 promotion ; N places → N promotions), dans l'ordre
d'ancienneté de la liste. Chaque membre promu est notifié (push + email) avec
une invitation à annuler s'il n'est finalement pas disponible.

Utilisé par :
  - l'annulation d'une réservation (1 place se libère),
  - l'augmentation de la capacité d'un cours plein (N places se libèrent).
"""
from typing import List

from sqlalchemy.orm import Session

from app.models.booking import Booking, BookingStatus
from app.models.course import Course
from app.models.member import Member
from app.services import notification_service


def _confirmed_count(course_id: int, db: Session) -> int:
    return (
        db.query(Booking)
        .filter(
            Booking.course_id == course_id,
            Booking.status == BookingStatus.confirmed,
        )
        .count()
    )


def promote_waitlist(course: Course, db: Session) -> List[Member]:
    """Promeut les premiers de la liste d'attente sur les places disponibles.

    Retourne la liste des membres promus (vide si aucune place / personne en attente).
    """
    free_spots = course.max_capacity - _confirmed_count(course.id, db)
    if free_spots <= 0:
        return []

    waiting = (
        db.query(Booking)
        .filter(
            Booking.course_id == course.id,
            Booking.status == BookingStatus.waitlist,
        )
        .order_by(Booking.booked_at, Booking.id)
        .limit(free_spots)
        .all()
    )
    if not waiting:
        return []

    for booking in waiting:
        booking.status = BookingStatus.confirmed
    db.commit()

    promoted: List[Member] = []
    for booking in waiting:
        member = db.query(Member).filter(Member.id == booking.member_id).first()
        if member:
            notification_service.notify_waitlist_promoted(db, member, course)
            promoted.append(member)

    return promoted
