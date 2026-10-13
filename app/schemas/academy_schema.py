from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class AcademyVideoCreate(BaseModel):
    title: str
    section: str
    youtube_id: str
    description: Optional[str] = None
    sort_order: int = 0
    unlimited_only: bool = False


class AcademyVideoUpdate(BaseModel):
    title: Optional[str] = None
    section: Optional[str] = None
    youtube_id: Optional[str] = None
    description: Optional[str] = None
    sort_order: Optional[int] = None
    unlimited_only: Optional[bool] = None


class AcademyVideoOut(BaseModel):
    id: int
    title: str
    section: str
    youtube_id: str
    description: Optional[str]
    sort_order: int
    unlimited_only: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}
