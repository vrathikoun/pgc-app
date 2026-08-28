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
    # Pass mensuels sans engagement (paiement unique, 30 jours glissants).
    PRICE_MONTH_UNLIMITED_CENTS: int = 15000     # 150 € illimité 1 mois
    PRICE_MONTH_TWO_PER_WEEK_CENTS: int = 10000  # 100 € 2 cours/sem 1 mois
    MONTH_PASS_VALIDITY_DAYS: int = 30
    # Lien envoyé par email après paiement pour créer son compte (app web).
    SIGNUP_URL: str = "https://app.polograpplingclub.com"
    # URL publique de l'API (pour construire les liens d'avatars servis en base).
    PUBLIC_API_URL: str = "https://pgc-app.onrender.com"
    # Fiche App Store (lien de téléchargement iOS dans les emails).
    APP_STORE_URL: str = "https://apps.apple.com/fr/app/id6795164799"

    class Config:
        env_file = ".env"


settings = Settings()