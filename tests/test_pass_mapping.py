"""Mapping montant payé → type de pass : un tarif mal mappé fait payer un an
pour 7 jours d'accès. Lancer : python tests/test_pass_mapping.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "test")

from app.services.stripe_service import _pass_for_amount  # noqa: E402


def test_pass_for_amount():
    assert _pass_for_amount(108000) == ("year_unlimited", 365)
    assert _pass_for_amount(78000) == ("year_two_per_week", 365)
    assert _pass_for_amount(15000) == ("month_unlimited", 30)
    assert _pass_for_amount(10000) == ("month_two_per_week", 30)
    # Open mat / cours à l'unité : 7 jours, une entrée.
    assert _pass_for_amount(500) == ("drop_in", 7)
    # Tarif inconnu au-dessus du seuil : surtout pas un pass 7 jours.
    assert _pass_for_amount(90000) == (None, None)


if __name__ == "__main__":
    test_pass_for_amount()
    print("✅ mapping des tarifs OK")
