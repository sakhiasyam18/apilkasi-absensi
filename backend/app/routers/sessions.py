from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.database import get_db
from app.models import (
    Session as DbSession,
    Class,
    ClassStudent,
    SessionParticipant,
    Student,
    Attendance,
    PointHistory,
    Capture,
)
from app.errors import AppError
from app.config import settings
from app.routers.attendance import get_session_progress

router = APIRouter(tags=["sessions"])


class SessionCreate(BaseModel):
    class_id: int
    activity_name: str
    session_date: str
    session_time: str
    meeting_number: int


class ParticipantAdd(BaseModel):
    student_id: int


def _format_session_detail(sess: DbSession, db: Session):
    participants = (
        db.query(SessionParticipant, Student)
        .join(Student, SessionParticipant.student_id == Student.id)
        .filter(SessionParticipant.session_id == sess.id)
        .all()
    )

    participants_info = []
    without_faces_count = 0

    for _, st in participants:
        has_face = bool(st.has_faces)
        participants_info.append({
            "student_id": st.id,
            "full_name": st.full_name,
            "nim": st.nim,
            "has_faces": has_face,
        })
        if not has_face:
            without_faces_count += 1

    progress = get_session_progress(sess.id, db)

    captures = (
        db.query(Capture)
        .filter(Capture.session_id == sess.id)
        .order_by(Capture.capture_no.asc())
        .all()
    )

    captures_info = [
        {
            "id": c.id,
            "capture_no": c.capture_no,
            "client_capture_id": c.client_capture_id,
            "image_width": c.image_width,
            "image_height": c.image_height,
            "created_at": c.created_at,
        }
        for c in captures
    ]

    return {
        "id": sess.id,
        "class_id": sess.class_id,
        "activity_name": sess.activity_name,
        "session_date": sess.session_date,
        "session_time": sess.session_time,
        "meeting_number": sess.meeting_number,
        "status": sess.status,
        "capture_count": sess.capture_count,
        "max_captures": settings.max_captures_per_session,
        "created_at": sess.created_at,
        "finalized_at": sess.finalized_at,
        "without_faces_count": without_faces_count,
        "participants": participants_info,
        "progress": progress,
        "captures": captures_info,
    }


@router.post("/sessions", status_code=201)
def create_session(sess_input: SessionCreate, db: Session = Depends(get_db)):
    cls = db.query(Class).filter(Class.id == sess_input.class_id).first()
    if not cls:
        raise AppError("class_not_found", "Kelas tidak ditemukan", 404)

    roster_links = (
        db.query(ClassStudent).filter(ClassStudent.class_id == sess_input.class_id).all()
    )
    if not roster_links:
        raise AppError("validation_error", "Kelas belum memiliki mahasiswa.", 422)

    new_sess = DbSession(
        class_id=sess_input.class_id,
        activity_name=sess_input.activity_name,
        session_date=sess_input.session_date,
        session_time=sess_input.session_time,
        meeting_number=sess_input.meeting_number,
    )
    db.add(new_sess)
    db.commit()
    db.refresh(new_sess)

    # Masukkan semua mahasiswa dari roster ke dalam sesi ini (BR-03)
    for link in roster_links:
        db.add(SessionParticipant(session_id=new_sess.id, student_id=link.student_id))

    db.commit()
    return _format_session_detail(new_sess, db)


@router.get("/sessions")
def list_sessions(class_id: Optional[int] = None, db: Session = Depends(get_db)):
    """Mengambil daftar sesi (opsional filter class_id) terurut terbaru dulu."""
    query = db.query(DbSession)
    if class_id:
        query = query.filter(DbSession.class_id == class_id)
    sessions = query.order_by(DbSession.id.desc()).all()
    return [_format_session_detail(s, db) for s in sessions]


@router.get("/sessions/{id}")
def get_session_detail(id: int, db: Session = Depends(get_db)):
    """Mengambil detail lengkap sesi presensi dan progres kehadiran."""
    sess = db.query(DbSession).filter(DbSession.id == id).first()
    if not sess:
        raise AppError("session_not_found", "Sesi tidak ditemukan", 404)
    return _format_session_detail(sess, db)


@router.post("/sessions/{id}/participants")
def add_session_participant(
    id: int, req: ParticipantAdd, db: Session = Depends(get_db)
):
    """Menambahkan mahasiswa ke peserta sesi aktif (BR-07, BR-08). Mahasiswa harus ada di roster kelas."""
    sess = db.query(DbSession).filter(DbSession.id == id).first()
    if not sess or sess.status == "final":
        raise AppError("invalid_session", "Sesi tidak valid atau sudah final", 409)

    # Cek apakah ada di roster kelas
    in_class = (
        db.query(ClassStudent)
        .filter(
            ClassStudent.class_id == sess.class_id,
            ClassStudent.student_id == req.student_id,
        )
        .first()
    )
    if not in_class:
        raise AppError(
            "student_not_in_class",
            "Mahasiswa belum ada di roster kelas sesi ini. Tambahkan ke kelas terlebih dahulu.",
            409,
        )

    # Idempoten: Cek apakah sudah jadi peserta sesi
    existing_part = (
        db.query(SessionParticipant)
        .filter(
            SessionParticipant.session_id == id,
            SessionParticipant.student_id == req.student_id,
        )
        .first()
    )
    if not existing_part:
        db.add(SessionParticipant(session_id=id, student_id=req.student_id))
        db.commit()

    return _format_session_detail(sess, db)


@router.post("/sessions/{id}/finalize")
def finalize_session(id: int, db: Session = Depends(get_db)):
    """Menyelesaikan sesi presensi, menandai tidak hadir, dan menghitung poin kelas (BR-10, BR-11, BR-12)."""
    sess = db.query(DbSession).filter(DbSession.id == id).first()
    if not sess:
        raise AppError("session_not_found", "Sesi tidak ditemukan", 404)
    if sess.status == "final":
        raise AppError("session_finalized", "Sesi sudah difinalisasi", 409)

    participants = (
        db.query(SessionParticipant, Student)
        .join(Student, SessionParticipant.student_id == Student.id)
        .filter(SessionParticipant.session_id == id)
        .all()
    )

    results = []

    # 1. Transaksi: Untuk peserta tanpa attendance, buat status tidak_hadir
    for _, st in participants:
        att = (
            db.query(Attendance)
            .filter(Attendance.session_id == id, Attendance.student_id == st.id)
            .first()
        )
        if not att:
            att = Attendance(
                session_id=id,
                student_id=st.id,
                status="tidak_hadir",
                method="auto",
            )
            db.add(att)
            db.flush()

        # 2. Catat Delta Poin (+10 hadir, -10 tidak hadir)
        delta_points = (
            settings.points_present if att.status == "hadir" else settings.points_absent
        )
        db.add(
            PointHistory(
                student_id=st.id,
                session_id=id,
                delta=delta_points,
                reason=att.status,
            )
        )

    # 3. Kunci Sesi
    sess.status = "final"
    sess.finalized_at = datetime.now().isoformat()
    db.commit()

    # 4. Ambil Total Poin Kelas per Mahasiswa (Design Spec Section 6 & 8.3)
    points_query = text("""
        SELECT s.id, COALESCE(SUM(ph.delta), 0) AS total_points
        FROM class_students cs
        JOIN students s ON s.id = cs.student_id
        LEFT JOIN sessions se ON se.class_id = cs.class_id
        LEFT JOIN point_history ph ON ph.student_id = s.id AND ph.session_id = se.id
        WHERE cs.class_id = :class_id
        GROUP BY s.id;
    """)
    totals = db.execute(points_query, {"class_id": sess.class_id}).fetchall()
    total_map = {row[0]: row[1] for row in totals}

    # Susun hasil kembalian resmi
    for _, st in participants:
        att = (
            db.query(Attendance)
            .filter(Attendance.session_id == id, Attendance.student_id == st.id)
            .first()
        )
        delta = (
            settings.points_present if att and att.status == "hadir" else settings.points_absent
        )
        results.append({
            "student_id": st.id,
            "full_name": st.full_name,
            "nim": st.nim,
            "status": att.status if att else "tidak_hadir",
            "method": att.method if att else "auto",
            "delta": delta,
            "class_total_points": total_map.get(st.id, 0),
        })

    return {
        "session_id": sess.id,
        "class_id": sess.class_id,
        "status": "final",
        "results": results,
    }