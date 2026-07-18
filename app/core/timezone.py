"""Fuseau horaire métier du club : Europe/Paris.

Convention de bout en bout :
- En base, les colonnes sont `timestamptz` : on y stocke des instants UTC.
- L'app mobile envoie des dates ISO avec offset ; les dates NAÏVES (anciens
  clients, Swagger…) sont interprétées comme de l'heure de Paris.
- Tout affichage humain (emails, push) se fait en heure de Paris via fmt_paris.
- Les notions de « semaine » (fenêtre de réservation, limite hebdo) sont des
  semaines civiles de Paris (lundi 00:00 heure de Paris).
"""
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

PARIS = ZoneInfo("Europe/Paris")


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def now_paris() -> datetime:
    return datetime.now(PARIS)


def as_paris(dt: datetime) -> datetime:
    """Datetime aware en heure de Paris. Les naïfs sont supposés déjà en heure de Paris."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=PARIS)
    return dt.astimezone(PARIS)


def as_utc(dt: datetime) -> datetime:
    """Datetime aware en UTC. Les naïfs sont supposés en heure de Paris."""
    return as_paris(dt).astimezone(timezone.utc)


def fmt_paris(dt: datetime, fmt: str = "%d/%m/%Y à %H:%M") -> str:
    """Formatte un instant pour l'affichage humain, en heure de Paris."""
    return as_paris(dt).strftime(fmt)


def paris_week_start(ref: datetime | None = None) -> datetime:
    """Lundi 00:00 (heure de Paris) de la semaine du datetime donné (défaut : maintenant)."""
    ref_paris = as_paris(ref) if ref is not None else now_paris()
    monday = ref_paris - timedelta(days=ref_paris.weekday())
    return monday.replace(hour=0, minute=0, second=0, microsecond=0)
