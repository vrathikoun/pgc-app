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
from email.utils import formataddr

from app.core.config import settings


def _wrap(html: str) -> str:
    """Enrobe le contenu dans un gabarit de marque (logo PGC en tête)."""
    logo = f"{settings.PUBLIC_API_URL.rstrip('/')}/logo.png"
    return f"""
    <div style="background:#0B0C10;padding:28px 0;font-family:-apple-system,Segoe UI,Roboto,sans-serif">
      <div style="max-width:520px;margin:0 auto;background:#15161B;border-radius:20px;overflow:hidden">
        <div style="text-align:center;padding:28px 0 8px">
          <img src="{logo}" alt="Polo Grappling Club" width="72" height="72"
               style="border-radius:16px" />
          <div style="color:#D8B56D;font-weight:800;letter-spacing:1px;margin-top:8px">
            POLO GRAPPLING CLUB
          </div>
        </div>
        <div style="color:#F7F4EA;padding:8px 28px 28px;line-height:1.5">
          {html}
        </div>
      </div>
    </div>
    """


def _send(to: str, subject: str, html: str) -> None:
    """Fonction interne d'envoi — ne pas appeler directement depuis les routers."""
    # En mode DEBUG, on logue juste sans envoyer
    if settings.DEBUG:
        print(f"[EMAIL] To: {to} | Subject: {subject}")
        return

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    # Nom affiché dans la boîte du destinataire (ex. "Polo Grappling Club").
    msg["From"] = formataddr((settings.APP_NAME, settings.EMAIL_FROM))
    msg["To"] = to
    msg.attach(MIMEText(_wrap(html), "html"))

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


def send_password_reset(first_name: str, email: str, code: str) -> None:
    """Code de réinitialisation du mot de passe (valable 15 minutes)."""
    _send(
        to=email,
        subject="Ton code de réinitialisation PGC",
        html=f"""
        <h2>Réinitialisation du mot de passe</h2>
        <p>Salut {first_name}, voici ton code de réinitialisation :</p>
        <p style="font-size:28px;font-weight:bold;letter-spacing:6px">{code}</p>
        <p>Il est valable 15 minutes. Si tu n'es pas à l'origine de cette
        demande, ignore simplement cet email.</p>
        """,
    )


def send_signup_after_payment(email: str) -> None:
    """Après un paiement Stripe : confirme et invite à créer/associer son compte."""
    from app.core.config import settings

    _send(
        to=email,
        subject="Paiement confirmé — active ton accès PGC 🥋",
        html=f"""
        <h2>Merci, ton paiement est confirmé !</h2>
        <p>Dernière étape pour accéder aux cours : crée ton compte
        <b>avec cette même adresse email</b> ({email}). Ton QR code d'accès
        sera alors actif à l'accueil.</p>
        <p style="margin:18px 0">
          <b>📱 iPhone / iPad :</b>
          <a href="{settings.APP_STORE_URL}">Télécharger sur l'App Store</a>
        </p>
        <p style="margin:18px 0">
          <b>🤖 Android :</b>
          <a href="{settings.PLAY_STORE_URL}">Télécharger sur Google Play</a>
        </p>
        <p style="margin:18px 0">
          <b>💻 Ordinateur :</b>
          <a href="{settings.SIGNUP_URL}">Ouvrir l'application web</a>
        </p>
        <p>À très vite sur les tatamis 💪</p>
        """,
    )


def send_pack_purchased(
    email: str, credits: int, valid_until: str, has_account: bool
) -> None:
    """Confirme l'achat d'un carnet et explique la règle du décompte."""
    from app.core.config import settings

    unite = credits == 1
    titre = "Ton cours à l'unité est actif 🥋" if unite else f"Ton carnet de {credits} cours est actif 🥋"
    solde = "<b>1 cours</b>, valable" if unite else f"<b>{credits} cours</b>, valables"
    compte = (
        "<p>Tu peux réserver dès maintenant depuis l'application.</p>"
        if has_account
        else f"""
        <p>Dernière étape : crée ton compte <b>avec cette même adresse</b>
        ({email}) pour réserver tes cours.</p>
        <p style="margin:14px 0">
          <a href="{settings.APP_STORE_URL}">iPhone</a> ·
          <a href="{settings.PLAY_STORE_URL}">Android</a> ·
          <a href="{settings.SIGNUP_URL}">application web</a>
        </p>"""
    )
    _send(
        to=email,
        subject=titre,
        html=f"""
        <h2>Merci, ton paiement est confirmé !</h2>
        <p>Tu disposes de {solde} jusqu'au <b>{valid_until}</b>.</p>
        {compte}
        <p style="opacity:.85">Comment ça marche : <b>un cours est décompté
        quand tu réserves</b>, et il t'est <b>rendu si tu annules</b> — même
        à la dernière minute. N'oublie pas de réserver ton créneau dans
        l'application : sans réservation, l'accès est refusé à l'entrée. Pense donc à annuler si tu ne peux pas venir :
        tu récupères ton cours et tu libères ta place.</p>
        <p>À très vite sur les tatamis 💪</p>
        """,
    )


def send_waitlist_pressure(
    first_name: str, email: str, course_name: str, start_time: str,
    waitlist_count: int, hours_left: int,
) -> None:
    """Cours complet avec longue liste d'attente : invite à libérer sa place."""
    pluriel = "personnes attendent" if waitlist_count > 1 else "personne attend"
    _send(
        to=email,
        subject=f"Ton cours dans {hours_left}h — {waitlist_count} en liste d'attente",
        html=f"""
        <h2>Ton cours commence dans {hours_left}h ⏳</h2>
        <p>Salut {first_name}, tu es inscrit à <b>{course_name}</b> ({start_time}).</p>
        <p>Le cours est <b>complet</b> et <b>{waitlist_count} {pluriel}</b> une place.
        Si tu ne peux finalement pas venir, annule ta réservation dans
        l'application : la première personne de la liste sera prévenue
        immédiatement et pourra prendre ta place.</p>
        <p style="opacity:.85">App &rarr; <i>Mes réservations</i> &rarr; le cours
        &rarr; <i>Me désinscrire</i>. 10 secondes.</p>
        <p>Si tu viens, parfait : à tout à l'heure 💪</p>
        """,
    )


def send_open_mat_pass(email: str, qr_url: str, valid_until: str) -> None:
    """Pass invité open mat : QR d'entrée envoyé par email (aucun compte requis)."""
    from app.core.config import settings

    _send(
        to=email,
        subject="Ton pass Open Mat PGC 🥋",
        html=f"""
        <h2>Paiement confirmé — voici ton pass</h2>
        <p>Présente ce QR code à l'accueil le jour de l'open mat :</p>
        <p style="text-align:center;margin:20px 0">
          <img src="{qr_url}" alt="QR pass open mat" width="220" height="220"
               style="background:#ffffff;padding:12px;border-radius:12px" />
        </p>
        <p><b>1 entrée</b>, valable jusqu'au <b>{valid_until}</b>.</p>
        <p style="font-size:13px;opacity:.85">Envie de venir plus souvent ?
        <a href="{settings.APP_STORE_URL}">iPhone</a> ·
        <a href="{settings.PLAY_STORE_URL}">Android</a> ·
        <a href="{settings.SIGNUP_URL}">application web</a></p>
        <p>À dimanche sur les tatamis 💪</p>
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


def send_waitlist_joined(
    first_name: str, email: str, course_name: str, start_time: str, position: int
) -> None:
    """Email confirmant l'ajout en liste d'attente, avec le numéro de position."""
    _send(
        to=email,
        subject=f"Liste d'attente — {course_name}",
        html=f"""
        <h2>Tu es en liste d'attente ⏳</h2>
        <p>Bonjour {first_name},</p>
        <p>Le cours <strong>{course_name}</strong> ({start_time}) est complet.
        Tu es <strong>n°{position}</strong> sur la liste d'attente.</p>
        <p>Si une place se libère, tu seras inscrit(e) automatiquement et prévenu(e)
        immédiatement.</p>
        """,
    )


def send_waitlist_promoted(first_name: str, email: str, course_name: str, start_time: str) -> None:
    """Email quand un membre passe automatiquement de la liste d'attente à confirmé."""
    _send(
        to=email,
        subject=f"Une place s'est libérée — {course_name} 🎉",
        html=f"""
        <h2>Bonne nouvelle !</h2>
        <p>Bonjour {first_name},</p>
        <p>Une place s'est libérée et tu es maintenant <strong>inscrit(e) automatiquement</strong> au cours :</p>
        <ul>
            <li><strong>Cours :</strong> {course_name}</li>
            <li><strong>Date :</strong> {start_time}</li>
        </ul>
        <p><strong>Si tu ne peux finalement pas venir, pense à annuler ta réservation</strong>
        pour laisser la place au membre suivant sur la liste.</p>
        """,
    )


def send_course_updated(
    first_name: str, email: str, course_name: str, start_time: str, changes_html: str
) -> None:
    """Email quand un cours sur lequel le membre est inscrit a été modifié."""
    _send(
        to=email,
        subject=f"Modification — {course_name}",
        html=f"""
        <h2>Ton cours a été modifié ✏️</h2>
        <p>Bonjour {first_name},</p>
        <p>Des changements ont été apportés au cours <strong>{course_name}</strong>
        (prévu le <strong>{start_time}</strong>) :</p>
        <ul>{changes_html}</ul>
        <p>Si ces changements ne te conviennent pas, pense à annuler ta réservation
        pour libérer ta place.</p>
        """,
    )


def send_course_cancelled(
    first_name: str, email: str, course_name: str, start_time: str
) -> None:
    """Email quand un cours sur lequel le membre est inscrit est annulé/supprimé."""
    _send(
        to=email,
        subject=f"Cours annulé — {course_name}",
        html=f"""
        <h2>Cours annulé ❌</h2>
        <p>Bonjour {first_name},</p>
        <p>Le cours <strong>{course_name}</strong> prévu le
        <strong>{start_time}</strong> a été <strong>annulé</strong>.</p>
        <p>Ta réservation a été automatiquement supprimée. Désolé pour la gêne,
        on se retrouve sur un prochain créneau 💪</p>
        """,
    )


def send_course_reminder(
    first_name: str, email: str, course_name: str, start_time: str
) -> None:
    """Email de rappel envoyé 24h avant le cours."""
    _send(
        to=email,
        subject=f"Rappel — {course_name} demain",
        html=f"""
        <h2>Rendez-vous demain 🥊</h2>
        <p>Bonjour {first_name},</p>
        <p>Petit rappel : tu es inscrit(e) au cours <strong>{course_name}</strong>
        prévu le <strong>{start_time}</strong>.</p>
        <p><strong>Si tu ne peux pas y assister, pense à annuler ta réservation</strong>
        pour libérer ta place et en faire profiter un membre de la liste d'attente.</p>
        <p>À demain sur les tatamis !</p>
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