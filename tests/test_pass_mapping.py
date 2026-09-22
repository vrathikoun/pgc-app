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
    assert _pass_for_amount(108000) == ("year_unlimited", 365, None)
    assert _pass_for_amount(78000) == ("year_two_per_week", 365, None)
    assert _pass_for_amount(15000) == ("month_unlimited", 30, None)
    assert _pass_for_amount(10000) == ("month_two_per_week", 30, None)
    # Open mat / cours à l'unité : 7 jours, une entrée.
    assert _pass_for_amount(500) == ("drop_in", 7, None)
    # Tarif inconnu au-dessus du seuil : surtout pas un pass 7 jours.
    assert _pass_for_amount(90000) == (None, None, None)
    # Un montant remisé n'est pas au catalogue (780 € - 15 % = 663 €) : c'est
    # pourquoi le webhook transmet amount_subtotal, le montant AVANT réduction.
    assert _pass_for_amount(66300) == (None, None, None)


def test_carnets():
    # Carnets : validité 1 an, crédits = nombre de cours achetés.
    assert _pass_for_amount(2500) == ("pack", 365, 1)
    assert _pass_for_amount(11000) == ("pack", 365, 5)
    assert _pass_for_amount(20000) == ("pack", 365, 10)
    assert _pass_for_amount(35000) == ("pack", 365, 20)
    # Le carnet 1 cours (25 €) prime sur la règle « petit montant = drop_in » :
    # il se décompte à la réservation, pas au scan.
    assert _pass_for_amount(2500)[0] != "drop_in"


if __name__ == "__main__":
    test_pass_for_amount()
    test_carnets()
    print("✅ mapping des tarifs et carnets OK")
