from sqlalchemy import create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from app.core.config import settings

engine = create_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# Petites migrations idempotentes — `Base.metadata.create_all` crée les tables
# manquantes mais n'ajoute PAS les colonnes manquantes sur une table déjà existante.
# On ajoute donc ici les nouvelles colonnes à la main (syntaxe PostgreSQL).
_LIGHTWEIGHT_MIGRATIONS = [
    "ALTER TABLE courses ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ",
    "ALTER TABLE members ADD COLUMN IF NOT EXISTS emergency_contact VARCHAR",
    # Le plan n'a plus de valeur par défaut : il vient de Stripe.
    "ALTER TABLE members ALTER COLUMN subscription_plan DROP NOT NULL",
    "ALTER TABLE members ALTER COLUMN subscription_plan DROP DEFAULT",
    # Emails insensibles à la casse au niveau SQL (citext) : toute comparaison
    # (login, webhook Stripe, pass d'accès…) ignore les majuscules, même dans
    # du code futur qui oublierait de normaliser.
    "CREATE EXTENSION IF NOT EXISTS citext",
    "ALTER TABLE members ALTER COLUMN email TYPE citext",
    "ALTER TABLE access_passes ALTER COLUMN email TYPE citext",
    # Pass mensuels (paiement unique 1 mois) en plus des pass à l'unité.
    "ALTER TABLE access_passes ADD COLUMN IF NOT EXISTS pass_type VARCHAR NOT NULL DEFAULT 'drop_in'",
]


def run_lightweight_migrations() -> None:
    """Applique les ALTER TABLE idempotents au démarrage."""
    with engine.begin() as conn:
        for statement in _LIGHTWEIGHT_MIGRATIONS:
            try:
                conn.execute(text(statement))
            except Exception as exc:  # ne jamais bloquer le démarrage
                print(f"[MIGRATION] ignorée ({statement}) : {exc}")


def get_db():
    """Dépendance FastAPI — injecte une session DB dans chaque route."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
