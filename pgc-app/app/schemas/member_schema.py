from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, field_validator

from app.models.member import MemberRole, SubscriptionStatus, BeltRank


def validate_password_72_bytes(v: str) -> str:
    if len(v.encode("utf-8")) > 72:
        raise ValueError("Password must be at most 72 bytes")
    return v


class MemberCreate(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    last_name: str
    phone: Optional[str] = None

    _validate_password = field_validator("password")(validate_password_72_bytes)


class MemberUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None
    belt_rank: Optional[str] = None


class AvatarUpdate(BaseModel):
    """Image encodée en base64 — format: data:image/jpeg;base64,/9j/..."""
    image_b64: str


class MemberAdminRoleUpdate(BaseModel):
    role: MemberRole


class MemberOut(BaseModel):
    id: int
    email: str
    first_name: str
    last_name: str
    phone: Optional[str]
    avatar_url: Optional[str]
    belt_rank: Optional[BeltRank]
    role: MemberRole
    is_active: bool
    subscription_status: SubscriptionStatus
    created_at: datetime

    model_config = {"from_attributes": True}


class LoginRequest(BaseModel):
    email: EmailStr
    password: str

    _validate_password = field_validator("password")(validate_password_72_bytes)


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    member: MemberOut