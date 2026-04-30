from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr

from app.models.member import MemberRole, SubscriptionStatus


class MemberCreate(BaseModel):
    """Données reçues lors de l'inscription."""
    email: EmailStr
    password: str          # mot de passe en clair (hashé avant stockage)
    first_name: str
    last_name: str
    phone: Optional[str] = None


class MemberUpdate(BaseModel):
    """Champs modifiables par le membre lui-même."""
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None


class MemberOut(BaseModel):
    """Données retournées par l'API — sans mot de passe ni stripe_customer_id."""
    id: int
    email: str
    first_name: str
    last_name: str
    phone: Optional[str]
    avatar_url: Optional[str]
    role: MemberRole
    is_active: bool
    subscription_status: SubscriptionStatus
    created_at: datetime

    model_config = {"from_attributes": True}


class LoginRequest(BaseModel):
    """Corps de la requête de connexion."""
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    """Réponse après connexion réussie."""
    access_token: str
    token_type: str = "bearer"
    member: MemberOut
