"""
Tâches planifiées — déclenchées par un cron externe (pas par un utilisateur).

Rappel 24h : prévient les membres inscrits (confirmés) qu'ils ont cours le
lendemain, en les invitant à annuler s'ils ne peuvent pas venir.

Sécurité : l'appelant doit fournir l'en-tête `X-Cron-Secret` égal à CRON_SECRET.
Mettre en place un cron (Render Cron Job, GitHub Actions, cron-job.org…) qui
appelle TOUTES LES HEURES :

    curl -X POST https://pgc-app.onrender.com/tasks/send-reminders \
         -H "X-Cron-Secret: <CRON_SECRET>"
"""
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import get_db
from app.models.booking import Booking, BookingStatus
from app.models.course import Course
from app.models.member import Member
from app.services import notification_service

router = APIRouter(prefix="/tasks", tags=["Tasks"])


def _require_cron_secret(x_cron_secret: str = Header(default="")) -> None:
    if not settings.CRON_SECRET or x_cron_secret != settings.CRON_SECRET:
        raise HTTPException(status_code=403, detail="Secret cron invalide")


@router.post("/send-reminders")
def send_reminders(
    _auth: None = Depends(_require_cron_secret),
    db: Session = Depends(get_db),
):
    """Envoie les rappels pour les cours qui commencent dans ~24h.

    À appeler toutes les heures. Chaque cours n'est rappelé qu'une fois
    (garde-fou via `reminder_sent_at`).
    """
    now = datetime.now(timezone.utc)
    window_start = now + timedelta(hours=23)
    window_end = now + timedelta(hours=24)

    courses = (
        db.query(Course)
        .filter(
            Course.start_time >= window_start,
            Course.start_time <= window_end,
            Course.reminder_sent_at.is_(None),
        )
        .all()
    )

    courses_notified = 0
    members_notified = 0

    for course in courses:
        members = (
            db.query(Member)
            .join(Booking, Booking.member_id == Member.id)
            .filter(
                Booking.course_id == course.id,
                Booking.status == BookingStatus.confirmed,
            )
            .all()
        )
        members = list({m.id: m for m in members}.values())

        if members:
            notification_service.send_course_reminder(db, members, course)
            members_notified += len(members)

        course.reminder_sent_at = now
        courses_notified += 1

    db.commit()

    return {
        "courses_processed": courses_notified,
        "members_notified": members_notified,
    }
