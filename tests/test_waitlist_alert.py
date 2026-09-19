"""Règle d'alerte H-8 / H-4 : elle décide si tous les inscrits d'un cours
reçoivent un mail. Lancer : python tests/test_waitlist_alert.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "test")

from app.routers.tasks import should_alert  # noqa: E402

SEUIL = 5


def test_should_alert():
    # Cours plein + liste d'attente au-dessus du seuil : on alerte.
    assert should_alert(confirmed=22, capacity=22, waitlist=6, threshold=SEUIL)
    # « Plus de 5 » : exactement 5 ne suffit pas.
    assert not should_alert(confirmed=22, capacity=22, waitlist=5, threshold=SEUIL)
    # Cours non plein : une annulation ne profite à personne.
    assert not should_alert(confirmed=21, capacity=22, waitlist=9, threshold=SEUIL)
    # Aucune liste d'attente : silence.
    assert not should_alert(confirmed=22, capacity=22, waitlist=0, threshold=SEUIL)
    # Surbooking (capacité baissée après coup) : on alerte quand même.
    assert should_alert(confirmed=24, capacity=22, waitlist=8, threshold=SEUIL)


if __name__ == "__main__":
    test_should_alert()
    print("✅ règle d'alerte OK")
