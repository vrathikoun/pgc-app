from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "Polo Grappling Club"
    DEBUG: bool = False
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""

    # Email SMTP
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    EMAIL_FROM: str = "polograpplingclub@gmail.com"

    # Push notifications (Firebase Cloud Messaging)
    # Colle ici le JSON complet du compte de service Firebase (sur une seule ligne).
    # Laisser vide => les push sont simplement loguées, jamais envoyées (comme DEBUG pour les emails).
    FIREBASE_CREDENTIALS_JSON: str = ""

    # Secret protégeant l'endpoint des tâches planifiées (rappels 24h).
    # Le cron externe doit envoyer ce secret dans l'en-tête X-Cron-Secret.
    CRON_SECRET: str = ""

    # Contrôle d'accès
    # Durée de validité d'un pass « cours à l'unité » (jours).
    DROP_IN_PASS_VALIDITY_DAYS: int = 7
    # Montants Stripe (centimes) → mapping abonnement. Adapter si tes tarifs changent.
    PRICE_UNLIMITED_CENTS: int = 9000    # 90 € illimité
    PRICE_TWO_PER_WEEK_CENTS: int = 6500  # 65 € 2 cours/semaine
    # Lien envoyé par email après paiement pour créer son compte.
    SIGNUP_URL: str = "https://polograpplingclub.com"

    class Config:
        env_file = ".env"


settings = Settings()