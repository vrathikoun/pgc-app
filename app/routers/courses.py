from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.booking import Booking, BookingStatus
from app.models.course import Course
from app.models.member import Member
from app.routers.members import get_current_member, require_admin
from app.schemas.course_schema import CourseCreate, CourseOut, CourseUpdate
from app.schemas.member_schema import MemberOut
from app.services import notification_service, waitlist_service

router = APIRouter(prefix="/courses", tags=["Courses"])


def _coach_name(coach_id: Optional[int], db: Session) -> str:
    if coach_id is None:
        return "aucun coach"
    coach = db.query(Member).filter(Member.id == coach_id).first()
    if not coach:
        return "coach inconnu"
    return f"{coach.first_name} {coach.last_name}".strip()


def _snapshot_affected(course_ids, db) -> list[tuple]:
    """Collecte (membres, nom, horaire) AVANT suppression, pour notifier ensuite."""
    snapshots = []
    for cid in course_ids:
        course = db.query(Course).filter(Course.id == cid).first()
        if not course:
            continue
        members = notification_service.active_members_for_course(cid, db)
        if members:
            snapshots.append((members, course.name, course.start_time))
    return snapshots


class BulkCourseDeleteRequest(BaseModel):
    course_ids: Optional[List[int]] = Field(default=None)
    same_series_as_course_id: Optional[int] = None
    delete_following_only: bool = True


def _spots_available(course: Course, db: Session) -> int:
    booked = (
        db.query(Booking)
        .filter(
            Booking.course_id == course.id,
            Booking.status == BookingStatus.confirmed,
        )
        .count()
    )
    return max(0, course.max_capacity - booked)


def _enrich(course: Course, db: Session) -> CourseOut:
    out = CourseOut.model_validate(course)
    out.spots_available = _spots_available(course, db)

    coach = course.coach
    if coach is None and course.coach_id is not None:
        coach = db.query(Member).filter(Member.id == course.coach_id).first()

    if coach is not None:
        out.coach = MemberOut.model_validate(coach)
        out.coach_first_name = coach.first_name
        out.coach_last_name = coach.last_name
        out.coach_avatar_url = coach.avatar_url

    return out


@router.get("/", response_model=List[CourseOut])
def list_courses(
    from_date: Optional[datetime] = None,
    to_date: Optional[datetime] = None,
    course_type: Optional[str] = None,
    coach_id: Optional[int] = None,
    _current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    q = db.query(Course)
    if from_date:
        q = q.filter(Course.start_time >= from_date)
    if to_date:
        q = q.filter(Course.start_time <= to_date)
    if course_type:
        q = q.filter(Course.course_type == course_type)
    if coach_id:
        q = q.filter(Course.coach_id == coach_id)

    courses = q.order_by(Course.start_time).all()
    return [_enrich(course, db) for course in courses]


@router.post("/bulk-delete")
def bulk_delete_courses(
    data: BulkCourseDeleteRequest,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    course_ids_to_delete = set(data.course_ids or [])

    if data.same_series_as_course_id is not None:
        ref = db.query(Course).filter(Course.id == data.same_series_as_course_id).first()
        if not ref:
            raise HTTPException(status_code=404, detail="Cours de référence introuvable")

        q = db.query(Course).filter(
            Course.name == ref.name,
            Course.course_type == ref.course_type,
            Course.level == ref.level,
            Course.coach_id == ref.coach_id,
            Course.max_capacity == ref.max_capacity,
        )

        if data.delete_following_only:
            q = q.filter(Course.start_time >= ref.start_time)

        candidates = q.all()

        for course in candidates:
            same_weekday = course.start_time.weekday() == ref.start_time.weekday()
            same_hour = course.start_time.hour == ref.start_time.hour
            same_minute = course.start_time.minute == ref.start_time.minute

            if same_weekday and same_hour and same_minute:
                course_ids_to_delete.add(course.id)

    if not course_ids_to_delete:
        raise HTTPException(status_code=400, detail="Aucun cours à supprimer")

    snapshots = _snapshot_affected(course_ids_to_delete, db)

    db.query(Booking).filter(Booking.course_id.in_(course_ids_to_delete)).delete(
        synchronize_session=False
    )

    deleted_count = (
        db.query(Course)
        .filter(Course.id.in_(course_ids_to_delete))
        .delete(synchronize_session=False)
    )

    db.commit()

    for members, name, start in snapshots:
        notification_service.notify_course_cancelled(db, members, name, start)

    return {
        "deleted_count": deleted_count,
        "deleted_course_ids": sorted(list(course_ids_to_delete)),
    }


@router.get("/{course_id}", response_model=CourseOut)
def get_course(
    course_id: int,
    _current: Member = Depends(get_current_member),
    db: Session = Depends(get_db),
):
    course = db.query(Course).filter(Course.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Cours introuvable")
    return _enrich(course, db)


@router.post("/", response_model=CourseOut, status_code=201)
def create_course(
    data: CourseCreate,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    course = Course(**data.model_dump())
    db.add(course)
    db.commit()
    db.refresh(course)
    return _enrich(course, db)


@router.put("/{course_id}", response_model=CourseOut)
def update_course(
    course_id: int,
    data: CourseUpdate,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    course = db.query(Course).filter(Course.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Cours introuvable")

    updates = data.model_dump(exclude_none=True)
    old_capacity = course.max_capacity

    # Détecte les changements notables AVANT de les appliquer, pour prévenir
    # les membres inscrits (coach, horaire, lieu/nom du cours…).
    changes: list[str] = []
    if "coach_id" in updates and updates["coach_id"] != course.coach_id:
        changes.append(
            f"Coach : {_coach_name(course.coach_id, db)} → "
            f"{_coach_name(updates['coach_id'], db)}"
        )
    if "start_time" in updates and updates["start_time"] != course.start_time:
        changes.append(
            f"Horaire : {course.start_time.strftime('%d/%m/%Y à %H:%M')} → "
            f"{updates['start_time'].strftime('%d/%m/%Y à %H:%M')}"
        )
    if "name" in updates and updates["name"] != course.name:
        changes.append(f"Nom : {course.name} → {updates['name']}")
    if "level" in updates and updates["level"] != course.level:
        changes.append(f"Niveau modifié : {updates['level'].value}")
    if "course_type" in updates and updates["course_type"] != course.course_type:
        changes.append(f"Type modifié : {updates['course_type'].value}")

    for field, value in updates.items():
        setattr(course, field, value)

    db.commit()
    db.refresh(course)

    if changes:
        notification_service.notify_course_changed(db, course, changes)

    # Si la capacité augmente, N places se libèrent → promotion auto des premiers
    # de la liste d'attente (chacun notifié + invité à annuler si indisponible).
    if "max_capacity" in updates and course.max_capacity > old_capacity:
        waitlist_service.promote_waitlist(course, db)

    return _enrich(course, db)


@router.delete("/{course_id}", status_code=204)
def delete_course(
    course_id: int,
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    course = db.query(Course).filter(Course.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Cours introuvable")

    # Collecte les inscrits avant suppression pour pouvoir les prévenir.
    affected_members = notification_service.active_members_for_course(course_id, db)
    course_name = course.name
    course_start = course.start_time

    db.query(Booking).filter(Booking.course_id == course_id).delete(
        synchronize_session=False
    )
    db.delete(course)
    db.commit()

    notification_service.notify_course_cancelled(
        db, affected_members, course_name, course_start
    )
    return None

@router.delete("/{course_id}/series")
def delete_course_series(
    course_id: int,
    mode: str = "following",  # single | following | all
    _admin: Member = Depends(require_admin),
    db: Session = Depends(get_db),
):
    course = db.query(Course).filter(Course.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Cours introuvable")

    # NOTE : la colonne `recurrence_group_id` n'existe pas encore dans le modèle.
    # On utilise getattr pour ne pas planter et on retombe sur la suppression simple.
    group_id = getattr(course, "recurrence_group_id", None)

    if mode == "single" or not group_id:
        ids = [course.id]
    else:
        q = db.query(Course).filter(Course.recurrence_group_id == group_id)

        if mode == "following":
            q = q.filter(Course.start_time >= course.start_time)
        elif mode != "all":
            raise HTTPException(status_code=400, detail="Mode invalide")

        ids = [c.id for c in q.all()]

    snapshots = _snapshot_affected(ids, db)

    db.query(Booking).filter(Booking.course_id.in_(ids)).delete(
        synchronize_session=False
    )
    deleted = db.query(Course).filter(Course.id.in_(ids)).delete(
        synchronize_session=False
    )
    db.commit()

    for members, name, start in snapshots:
        notification_service.notify_course_cancelled(db, members, name, start)

    return {"deleted_count": deleted, "deleted_course_ids": ids}