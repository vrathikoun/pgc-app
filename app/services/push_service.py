"""
Push Service — envoi de notifications push via Firebase Cloud Messaging (FCM).

Configuration : colle le JSON du compte de service Firebase dans la variable
d'environnement FIREBASE_CREDENTIALS_JSON (voir README → section Notifications push).

Si FIREBASE_CREDENTIALS_JSON est vide (ex. en développement ou tant que Firebase
n'est pas configuré), les push sont simplement loguées dans le terminal et JAMAIS
envoyées — exactement comme le mode DEBUG du service email. Le reste de l'app
continue de fonctionner normalement.
"""
import json
from typing import List, Optional

from app.core.config import settings

_init_attempted = False
_messaging = None  # module firebase_admin.messaging si l'init a réussi


def _ensure_initialized() -> bool:
    """Initialise Firebase une seule fois. Retourne True si les push sont actives."""
    global _init_attempted, _messaging

    if _init_attempted:
        return _messaging is not None

    _init_attempted = True

    if not settings.FIREBASE_CREDENTIALS_JSON.strip():
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials, messaging

        if not firebase_admin._apps:
            cred = credentials.Certificate(json.loads(settings.FIREBASE_CREDENTIALS_JSON))
            firebase_admin.initialize_app(cred)

        _messaging = messaging
        return True
    except Exception as exc:
        print(f"[PUSH] Initialisation Firebase impossible : {exc}")
        _messaging = None
        return False


def send_to_tokens(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> List[str]:
    """Envoie une push à une liste de tokens d'appareils.

    Retourne la liste des tokens devenus invalides (à supprimer en base).
    """
    tokens = [t for t in tokens if t]
    if not tokens:
        return []

    if not _ensure_initialized():
        print(f"[PUSH] (non configuré) « {title} » → {len(tokens)} appareil(s)")
        return []

    messaging = _messaging
    # FCM accepte au maximum 500 tokens par appel multicast.
    invalid_tokens: List[str] = []
    str_data = {k: str(v) for k, v in (data or {}).items()}

    for i in range(0, len(tokens), 500):
        batch = tokens[i : i + 500]
        message = messaging.MulticastMessage(
            tokens=batch,
            notification=messaging.Notification(title=title, body=body),
            data=str_data,
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default", badge=1),
                ),
            ),
            android=messaging.AndroidConfig(priority="high"),
        )
        try:
            response = messaging.send_each_for_multicast(message)
        except Exception as exc:
            print(f"[PUSH] Échec d'envoi : {exc}")
            continue

        for token, result in zip(batch, response.responses):
            if not result.success:
                err = getattr(result.exception, "code", "")
                # Tokens définitivement morts → à nettoyer en base.
                if "registration-token-not-registered" in str(err) or "invalid-argument" in str(err):
                    invalid_tokens.append(token)

    return invalid_tokens
