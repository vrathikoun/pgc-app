from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from datetime import datetime, timezone

from app.database import get_db
from app.models.academy_video import AcademyVideo
from app.models.access_pass import UNLIMITED_PASSES, AccessPass
from app.models.member import (
    Member,
    MemberRole,
    SubscriptionPlan,
    SubscriptionStatus,
)
from app.routers.members import get_current_member, require_admin
from app.schemas.academy_schema import AcademyVideoCreate, AcademyVideoOut, AcademyVideoUpdate

router = APIRouter(prefix="/academy", tags=["Academy"])


def _acces_illimite(member: Member, db: Session) -> bool:
    """Le membre a-t-il droit aux contenus réservés aux formules illimitées ?

    Le staff voit tout. Sinon il faut un abonnement illimité en cours, ou un
    pass illimité valide (mensuel, 10 mois, annuel). Les formules 2 cours par
    semaine, les carnets et les cours d'essai n'y donnent pas droit.
    """
    if member.role in (MemberRole.admin, MemberRole.coach):
        return True

    if (
        member.subscription_plan == SubscriptionPlan.unlimited
        and member.subscription_status
        in (SubscriptionStatus.active, SubscriptionStatus.trial)
    ):
        return True

    return (
        db.query(AccessPass)
        .filter(
            AccessPass.email == member.email,
            AccessPass.pass_type.in_(tuple(UNLIMITED_PASSES)),
            AccessPass.expires_at > datetime.now(timezone.utc),
        )
        .first()
        is not None
    )


@router.get("/videos", response_model=List[AcademyVideoOut])
def list_videos(
    current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    q = db.query(AcademyVideo)
    if not _acces_illimite(current, db):
        q = q.filter(AcademyVideo.unlimited_only.is_(False))
    return q.order_by(
        AcademyVideo.section, AcademyVideo.sort_order, AcademyVideo.id
    ).all()


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
