"""Carnets de cours : un crédit par réservation, rendu dès qu'elle est annulée.

Le décompte a lieu à la réservation (pas au scan) : il ne dépend donc pas de la
présence d'un coach à l'accueil. Une réservation en liste d'attente mobilise
aussi un crédit — elle le rend si le membre se désinscrit.
"""
from typing import Sequence

from sqlalchemy.orm import Session

from app.models.access_pass import AccessPass
from app.models.booking import Booking, BookingStatus


def consume(booking: Booking, access_pass: AccessPass, db: Session) -> None:
    """Décompte un cours du carnet et note lequel a payé la réservation."""
    access_pass.credits_remaining = (access_pass.credits_remaining or 0) - 1
    booking.access_pass_id = access_pass.id
    db.commit()


def refund(booking: Booking, db: Session) -> bool:
    """Rend le crédit d'une réservation. Sans effet si elle n'en mobilisait pas.

    Le lien est effacé au passage : un second appel ne re-crédite rien.
    """
    if not booking.access_pass_id:
        return False

    access_pass = (
        db.query(AccessPass)
        .filter(AccessPass.id == booking.access_pass_id)
        .first()
    )
    if access_pass is not None and access_pass.credits_remaining is not None:
        access_pass.credits_remaining += 1
    booking.access_pass_id = None
    db.commit()
    return True


def refund_for_courses(course_ids: Sequence[int], db: Session) -> int:
    """Rend leurs crédits avant la suppression d'un ou plusieurs cours.

    Sans cela, annuler un cours ferait perdre un cours de carnet aux inscrits.
    """
    if not course_ids:
        return 0

    bookings = (
        db.query(Booking)
        .filter(
            Booking.course_id.in_(course_ids),
            Booking.access_pass_id.isnot(None),
            Booking.status.in_([BookingStatus.confirmed, BookingStatus.waitlist]),
        )
        .all()
    )
    for booking in bookings:
        refund(booking, db)
    return len(bookings)
