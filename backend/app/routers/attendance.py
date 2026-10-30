import os
import hashlib
from typing import Optional, List
from fastapi import APIRouter, Depends, UploadFile, File, Form, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.database import get_db
from app.models import (
    Session as DbSession,
    Capture,
    CaptureFace,
    Attendance,
    SessionParticipant,
    Student,
    FaceEmbedding,
)
from app.errors import AppError
from app.config import settings
from app.services import face_engine
from app.services.image_utils import load_for_recognition
from app.services.matching import match_faces_hungarian

router = APIRouter(tags=["attendance"])


def get_session_progress(session_id: int, db: Session):
    """Menghitung progres peserta sesi (identified vs unidentified) sesuai Design Spec 8.3."""
    participants = (
        db.query(SessionParticipant, Student)
        .join(Student, SessionParticipant.student_id == Student.id)
        .filter(SessionParticipant.session_id == session_id)
        .all()
    )

    attendances = db.query(Attendance).filter(Attendance.session_id == session_id).all()
    att_map = {a.student_id: a for a in attendances}

    identified = []
    unidentified = []

    for _, st in participants:
        att = att_map.get(st.id)
        if att and att.status == "hadir":
            identified.append({
                "student_id": st.id,
                "full_name": st.full_name,
                "nim": st.nim,
                "score": att.match_score,
                "method": att.method,
            })
        else:
            unidentified.append({
                "student_id": st.id,
                "full_name": st.full_name,
                "nim": st.nim,
                "has_faces": bool(st.has_faces),
            })

    return {
        "total_participants": len(participants),
        "identified": identified,
        "unidentified": unidentified,
    }


def format_capture_response(capture: Capture, db: Session):
    """Menyusun struktur respons pengenalan wajah lengkap dengan faces dan progress."""
    c_faces = db.query(CaptureFace).filter(CaptureFace.capture_id == capture.id).all()
    faces_data = []

    for cf in c_faces:
        st = None
        if cf.student_id:
            st = db.query(Student).filter(Student.id == cf.student_id).first()

        faces_data.append({
            "face_id": cf.id,
            "bbox": {
                "x": cf.bbox_x,
                "y": cf.bbox_y,
                "w": cf.bbox_w,
                "h": cf.bbox_h,
            },
            "status": cf.status,
            "student_id": cf.student_id,
            "full_name": st.full_name if st else None,
            "nim": st.nim if st else None,
            "score": cf.match_score,
        })

    progress = get_session_progress(capture.session_id, db)

    return {
        "capture_id": capture.id,
        "capture_no": capture.capture_no,
        "max_captures": settings.max_captures_per_session,
        "image_width": capture.image_width,
        "image_height": capture.image_height,
        "faces": faces_data,
        "progress": progress,
    }


@router.post("/attendance/recognize")
async def recognize_attendance(
    session_id: int = Form(...),
    client_capture_id: str = Form(...),
    image: UploadFile = File(...),
    class_id: Optional[int] = Form(None),
    x_content_sha256: Optional[str] = Header(None, alias="X-Content-SHA256"),
    db: Session = Depends(get_db),
):
    # 1. Validasi Sesi & Idempotensi (Cegah duplikat jika jaringan buruk)
    sess = db.query(DbSession).filter(DbSession.id == session_id).first()
    if not sess or sess.status == "final":
        raise AppError("invalid_session", "Sesi tidak valid atau sudah final", 409)

    existing_capture = (
        db.query(Capture)
        .filter(Capture.client_capture_id == client_capture_id)
        .first()
    )
    if existing_capture:
        # Kembalikan hasil yang sudah tersimpan tanpa memproses ulang (aman untuk retry)
        return format_capture_response(existing_capture, db)

    if sess.capture_count >= settings.max_captures_per_session:
        raise AppError("capture_limit_reached", "Batas jepretan kelas tercapai", 409)

    content = await image.read()

    # Validasi checksum opsional (BR-13)
    if x_content_sha256:
        calculated_sha = hashlib.sha256(content).hexdigest()
        if calculated_sha.lower() != x_content_sha256.lower():
            raise AppError("checksum_mismatch", "SHA-256 header tidak cocok", 400)

    # 2. Proses Gambar & Deteksi Wajah (AI InsightFace)
    bgr_image, (img_w, img_h) = load_for_recognition(content, settings.max_image_side)
    detected_faces = face_engine.face_app_instance.analyze(bgr_image)
    valid_faces = [f for f in detected_faces if f.det_score >= settings.min_det_score]

    # 3. Muat Data Wajah Peserta Sesi (Roster)
    participants = (
        db.query(SessionParticipant)
        .filter(SessionParticipant.session_id == session_id)
        .all()
    )
    participant_ids = [p.student_id for p in participants]

    registered_data = []
    for pid in participant_ids:
        embs = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == pid).all()
        if embs:
            registered_data.append({
                "student_id": pid,
                "embeddings": [e.embedding for e in embs],
            })

    # 4. Pencocokan Wajah (Matching Hungarian)
    detected_embeddings = [f.normed_embedding for f in valid_faces]
    matches, unmatched = match_faces_hungarian(
        detected_embeddings, registered_data, settings.match_threshold
    )

    # 5. Simpan Hasil ke Database (Transaksi)
    os.makedirs(settings.storage_dir, exist_ok=True)
    img_path = os.path.join(settings.storage_dir, f"{client_capture_id}.jpg")
    with open(img_path, "wb") as f:
        f.write(content)

    sess.capture_count += 1
    new_capture = Capture(
        session_id=session_id,
        capture_no=sess.capture_count,
        client_capture_id=client_capture_id,
        image_path=img_path,
        image_width=img_w,
        image_height=img_h,
    )
    db.add(new_capture)
    db.commit()
    db.refresh(new_capture)

    # Simpan Wajah Dikenali & Kehadiran (Merge-Max)
    for match in matches:
        idx = match["detected_index"]
        face_data = valid_faces[idx]
        bbox = face_data.bbox

        cf = CaptureFace(
            capture_id=new_capture.id,
            bbox_x=float(bbox[0]),
            bbox_y=float(bbox[1]),
            bbox_w=float(bbox[2] - bbox[0]),
            bbox_h=float(bbox[3] - bbox[1]),
            det_score=float(face_data.det_score),
            student_id=match["student_id"],
            match_score=float(match["score"]),
            status="identified",
        )
        db.add(cf)

        # Upsert Kehadiran (Merge Max Score)
        att = (
            db.query(Attendance)
            .filter(
                Attendance.session_id == session_id,
                Attendance.student_id == match["student_id"],
            )
            .first()
        )
        if not att:
            db.add(
                Attendance(
                    session_id=session_id,
                    student_id=match["student_id"],
                    status="hadir",
                    match_score=float(match["score"]),
                    method="auto",
                )
            )
        elif att.match_score is None or match["score"] > att.match_score:
            att.match_score = float(match["score"])

    # Simpan Wajah Tidak Dikenal (Unknown)
    for idx in unmatched:
        bbox = valid_faces[idx].bbox
        cf = CaptureFace(
            capture_id=new_capture.id,
            bbox_x=float(bbox[0]),
            bbox_y=float(bbox[1]),
            bbox_w=float(bbox[2] - bbox[0]),
            bbox_h=float(bbox[3] - bbox[1]),
            det_score=float(valid_faces[idx].det_score),
            status="unknown",
        )
        db.add(cf)

    db.commit()
    return format_capture_response(new_capture, db)


class ConfirmRequest(BaseModel):
    session_id: int
    student_id: int
    face_id: Optional[int] = None


@router.post("/attendance/confirm")
def confirm_attendance(req: ConfirmRequest, db: Session = Depends(get_db)):
    """Konfirmasi kehadiran manual oleh dosen untuk wajah yang tidak dikenali (BR-07, BR-08)."""
    sess = db.query(DbSession).filter(DbSession.id == req.session_id).first()
    if not sess or sess.status == "final":
        raise AppError("invalid_session", "Sesi tidak valid atau sudah final", 409)

    # Verifikasi bahwa mahasiswa adalah peserta sesi
    part = (
        db.query(SessionParticipant)
        .filter(
            SessionParticipant.session_id == req.session_id,
            SessionParticipant.student_id == req.student_id,
        )
        .first()
    )
    if not part:
        raise AppError("student_not_participant", "Mahasiswa bukan peserta sesi ini", 404)

    # Upsert Attendance
    att = (
        db.query(Attendance)
        .filter(
            Attendance.session_id == req.session_id,
            Attendance.student_id == req.student_id,
        )
        .first()
    )
    if not att:
        db.add(
            Attendance(
                session_id=req.session_id,
                student_id=req.student_id,
                status="hadir",
                method="manual",
            )
        )
    elif att.method != "auto":
        att.status = "hadir"
        att.method = "manual"

    # Update CaptureFace jika face_id diberikan
    if req.face_id:
        cf = db.query(CaptureFace).filter(CaptureFace.id == req.face_id).first()
        if cf:
            cf.status = "confirmed"
            cf.student_id = req.student_id

    db.commit()
    return get_session_progress(req.session_id, db)


@router.get("/attendance")
def get_attendance_list(session_id: Optional[int] = None, db: Session = Depends(get_db)):
    """Mengambil riwayat kehadiran untuk sesi tertentu atau seluruh sesi."""
    query = db.query(Attendance)
    if session_id:
        query = query.filter(Attendance.session_id == session_id)
    return query.all()