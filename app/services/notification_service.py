"""
Notification Service — orchestre les notifications membres (push + email).

Point d'entrée unique appelé par les routers. Pour chaque évènement, on envoie :
  1. une push FCM aux appareils du membre (push_service),
  2. un email en parallèle (email_service) — utile comme filet tant que les push
     ne sont pas configurées, et pour prévenir même app fermée / désinstallée.

Les tokens FCM devenus invalides sont nettoyés automatiquement en base.
"""
from datetime import datetime
from typing import List, Sequence

from sqlalchemy.orm import Session

from app.core.timezone import fmt_paris
from app.models.booking import Booking, BookingStatus
from app.models.course import Course
from app.models.device_token import DeviceToken
from app.models.member import Member
from app.services import email_service, push_service


def _fmt(dt: datetime) -> str:
    return fmt_paris(dt)


def active_members_for_course(course_id: int, db: Session) -> List[Member]:
    """Membres avec une réservation active (confirmée ou liste d'attente) sur ce cours."""
    rows = (
        db.query(Member)
        .join(Booking, Booking.member_id == Member.id)
        .filter(
            Booking.course_id == course_id,
            Booking.status.in_([BookingStatus.confirmed, BookingStatus.waitlist]),
        )
        .all()
    )
    # Dédoublonne par id (un membre = une notif même s'il a plusieurs lignes).
    return list({m.id: m for m in rows}.values())


def _push_to_members(
    db: Session, members: Sequence[Member], title: str, body: str, data: dict
) -> None:
    member_ids = [m.id for m in members]
    if not member_ids:
        return

    token_rows = (
        db.query(DeviceToken).filter(DeviceToken.member_id.in_(member_ids)).all()
    )
    tokens = [row.token for row in token_rows]
    if not tokens:
        return

    invalid = push_service.send_to_tokens(tokens, title, body, data)
    if invalid:
        db.query(DeviceToken).filter(DeviceToken.token.in_(invalid)).delete(
            synchronize_session=False
        )
        db.commit()


def notify_course_changed(db: Session, course: Course, changes: List[str]) -> None:
    """Prévient les inscrits qu'un cours a été modifié (coach, horaire, etc.)."""
    members = active_members_for_course(course.id, db)
    if not members or not changes:
        return

    when = _fmt(course.start_time)
    _push_to_members(
        db,
        members,
        title=f"Cours modifié : {course.name}",
        body=" · ".join(changes),
        data={"type": "course_updated", "course_id": course.id},
    )
    changes_html = "".join(f"<li>{c}</li>" for c in changes)
    for m in members:
        email_service.send_course_updated(
            m.first_name, m.email, course.name, when, changes_html
        )


def notify_course_cancelled(
    db: Session, members: Sequence[Member], course_name: str, start_time: datetime
) -> None:
    """Prévient les inscrits qu'un cours est annulé/supprimé.

    Les membres doivent être collectés AVANT la suppression du cours/réservations.
    """
    if not members:
        return

    when = _fmt(start_time)
    _push_to_members(
        db,
        members,
        title=f"Cours annulé : {course_name}",
        body=f"Le cours du {when} a été annulé.",
        data={"type": "course_cancelled"},
    )
    for m in members:
        email_service.send_course_cancelled(m.first_name, m.email, course_name, when)


def notify_waitlist_joined(
    db: Session, member: Member, course: Course, position: int
) -> None:
    """Confirme l'ajout en liste d'attente avec le numéro de position."""
    when = _fmt(course.start_time)
    _push_to_members(
        db,
        [member],
        title=f"Liste d'attente : {course.name}",
        body=f"Cours complet — tu es n°{position} en liste d'attente.",
        data={"type": "waitlist_joined", "course_id": course.id, "position": position},
    )
    email_service.send_waitlist_joined(
        member.first_name, member.email, course.name, when, position
    )


def notify_waitlist_promoted(db: Session, member: Member, course: Course) -> None:
    """Prévient un membre promu automatiquement depuis la liste d'attente.

    Insiste sur l'invitation à annuler s'il n'est finalement pas disponible.
    """
    when = _fmt(course.start_time)
    _push_to_members(
        db,
        [member],
        title=f"Une place s'est libérée : {course.name} 🎉",
        body=(
            f"Tu es inscrit(e) automatiquement pour le {when}. "
            "Si tu ne peux pas venir, annule pour libérer ta place."
        ),
        data={"type": "waitlist_promoted", "course_id": course.id},
    )
    email_service.send_waitlist_promoted(
        member.first_name, member.email, course.name, when
    )


def send_course_reminder(db: Session, members: Sequence[Member], course: Course) -> None:
    """Rappel 24h avant le cours, avec invitation à annuler en cas d'empêchement."""
    if not members:
        return

    when = _fmt(course.start_time)
    _push_to_members(
        db,
        members,
        title=f"Rappel : {course.name} demain",
        body=(
            f"Cours demain à {fmt_paris(course.start_time, '%H:%M')}. "
            "Si tu ne peux pas venir, pense à annuler pour libérer ta place."
        ),
        data={"type": "course_reminder", "course_id": course.id},
    )
    for m in members:
        email_service.send_course_reminder(m.first_name, m.email, course.name, when)
