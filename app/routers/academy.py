from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.academy_video import AcademyVideo
from app.models.member import Member
from app.routers.members import get_current_member, require_admin
from app.schemas.academy_schema import AcademyVideoCreate, AcademyVideoOut, AcademyVideoUpdate

router = APIRouter(prefix="/academy", tags=["Academy"])


@router.get("/videos", response_model=List[AcademyVideoOut])
def list_videos(
    _current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    return (
        db.query(AcademyVideo)
        .order_by(AcademyVideo.section, AcademyVideo.sort_order, AcademyVideo.id)
        .all()
    )


@router.post("/videos", response_model=AcademyVideoOut, status_code=201)
def create_video(
    data: AcademyVideoCreate,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    video = AcademyVideo(**data.model_dump())
    db.add(video)
    db.commit()
    db.refresh(video)
    return video


@router.put("/videos/{video_id}", response_model=AcademyVideoOut)
def update_video(
    video_id: int,
    data: AcademyVideoUpdate,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    video = db.query(AcademyVideo).filter(AcademyVideo.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Vidéo introuvable")

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(video, field, value)

    db.commit()
    db.refresh(video)
    return video


@router.delete("/videos/{video_id}", status_code=204)
def delete_video(
    video_id: int,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    video = db.query(AcademyVideo).filter(AcademyVideo.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Vidéo introuvable")

    db.delete(video)
    db.commit()
    return None
