"""
Email Service — utilise SMTP standard (Gmail, Brevo, Resend, etc.)
Aucune dépendance lourde : juste smtplib de la stdlib Python.

Pour démarrer gratuitement : Brevo (ex-Sendinblue) → 300 emails/jour gratuits.
Configure dans .env :
    SMTP_HOST=smtp-relay.brevo.com
    SMTP_PORT=587
    SMTP_USER=ton@email.com
    SMTP_PASSWORD=ton_api_key
    EMAIL_FROM=noreply@tonclub.com
"""
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import settings


def _send(to: str, subject: str, html: str) -> None:
    """Fonction interne d'envoi — ne pas appeler directement depuis les routers."""
    # En mode DEBUG, on logue juste sans envoyer
    if settings.DEBUG:
        print(f"[EMAIL] To: {to} | Subject: {subject}")
        return

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = settings.EMAIL_FROM
    msg["To"] = to
    msg.attach(MIMEText(html, "html"))

    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
        server.starttls()
        server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        server.sendmail(settings.EMAIL_FROM, to, msg.as_string())


def send_welcome(first_name: str, email: str) -> None:
    """Email de bienvenue après inscription."""
    _send(
        to=email,
        subject=f"Bienvenue {first_name} 🥊",
        html=f"""
        <h2>Bienvenue {first_name} !</h2>
        <p>Ton compte est créé. Tu peux dès maintenant réserver tes cours.</p>
        <p>À très vite sur les tatamis 💪</p>
        """,
    )


def send_booking_confirmation(first_name: str, email: str, course_name: str, start_time: str) -> None:
    """Email de confirmation de réservation."""
    _send(
        to=email,
        subject=f"Réservation confirmée — {course_name}",
        html=f"""
        <h2>Réservation confirmée ✅</h2>
        <p>Bonjour {first_name},</p>
        <p>Ta place est réservée pour :</p>
        <ul>
            <li><strong>Cours :</strong> {course_name}</li>
            <li><strong>Date :</strong> {start_time}</li>
        </ul>
        <p>En cas d'empêchement, pense à annuler pour libérer ta place.</p>
        """,
    )


def send_booking_cancellation(first_name: str, email: str, course_name: str) -> None:
    """Email de confirmation d'annulation."""
    _send(
        to=email,
        subject=f"Annulation — {course_name}",
        html=f"""
        <h2>Réservation annulée</h2>
        <p>Bonjour {first_name},</p>
        <p>Ta réservation pour <strong>{course_name}</strong> a bien été annulée.</p>
        <p>À bientôt !</p>
        """,
    )


def send_waitlist_promoted(first_name: str, email: str, course_name: str, start_time: str) -> None:
    """Email quand un membre passe de la liste d'attente à confirmé."""
    _send(
        to=email,
        subject=f"Une place s'est libérée — {course_name} 🎉",
        html=f"""
        <h2>Bonne nouvelle !</h2>
        <p>Bonjour {first_name},</p>
        <p>Une place s'est libérée et tu es maintenant <strong>inscrit(e)</strong> au cours :</p>
        <ul>
            <li><strong>Cours :</strong> {course_name}</li>
            <li><strong>Date :</strong> {start_time}</li>
        </ul>
        """,
    )


def send_subscription_confirmed(first_name: str, email: str, plan: str, end_date: str) -> None:
    """Email de confirmation d'abonnement."""
    _send(
        to=email,
        subject="Abonnement activé ✅",
        html=f"""
        <h2>Abonnement activé</h2>
        <p>Bonjour {first_name},</p>
        <p>Ton abonnement <strong>{plan}</strong> est actif jusqu'au <strong>{end_date}</strong>.</p>
        <p>Tu peux maintenant réserver tous tes cours 💪</p>
        """,
    )