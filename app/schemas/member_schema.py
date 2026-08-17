from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, field_validator

from app.models.member import MemberRole, SubscriptionStatus, BeltRank, SubscriptionPlan


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
    emergency_contact: Optional[str] = None

    _validate_password = field_validator("password")(validate_password_72_bytes)


class MemberUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    emergency_contact: Optional[str] = None
    avatar_url: Optional[str] = None
    belt_rank: Optional[str] = None
    weekly_booking_limit: Optional[int] = None
    subscription_plan: Optional[SubscriptionPlan] = None


class AvatarUpdate(BaseModel):
    image_b64: str


class MemberAdminRoleUpdate(BaseModel):
    role: MemberRole


class MemberOut(BaseModel):
    id: int
    email: str
    first_name: str
    last_name: str
    phone: Optional[str]
    emergency_contact: Optional[str] = None
    avatar_url: Optional[str]
    belt_rank: Optional[BeltRank] | Optional[str] = None
    role: MemberRole
    is_active: bool
    subscription_status: SubscriptionStatus
    weekly_booking_limit: Optional[int] = None
    created_at: datetime
    subscription_plan: Optional[SubscriptionPlan] = None

    model_config = {"from_attributes": True}


class LoginRequest(BaseModel):
    email: EmailStr
    password: str

    _validate_password = field_validator("password")(validate_password_72_bytes)


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    member: MemberOut
