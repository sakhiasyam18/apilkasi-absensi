from fastapi import APIRouter, Depends, UploadFile, File, Form
from sqlalchemy.orm import Session
import os, uuid
import numpy as np

from app.database import get_db
from app.models import Session as DbSession, Capture, CaptureFace, Attendance, SessionParticipant, Student, FaceEmbedding
from app.errors import AppError
from app.config import settings
from app.services import face_engine
from app.services.image_utils import load_for_recognition
from app.services.matching import match_faces_hungarian

router = APIRouter(tags=["attendance"])

@router.post("/attendance/recognize")
async def recognize_attendance(
    session_id: int = Form(...),
    client_capture_id: str = Form(...),
    image: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # 1. Validasi Sesi & Idempotensi (Cegah duplikat jika jaringan buruk)
    sess = db.query(DbSession).filter(DbSession.id == session_id).first()
    if not sess or sess.status == 'final':
        raise AppError("invalid_session", "Sesi tidak valid atau sudah final", 409)
        
    existing_capture = db.query(Capture).filter(Capture.client_capture_id == client_capture_id).first()
    if existing_capture:
        return {"message": "Hasil sudah ada (Idempotent)", "capture_id": existing_capture.id} # Versi sederhana agar cepat
        
    if sess.capture_count >= settings.max_captures_per_session:
        raise AppError("capture_limit_reached", "Batas jepretan kelas tercapai", 409)

    # 2. Proses Gambar & Deteksi Wajah (AI InsightFace)
    content = await image.read()
    bgr_image, (img_w, img_h) = load_for_recognition(content, settings.max_image_side)
    detected_faces = face_engine.face_app_instance.analyze(bgr_image)
    valid_faces = [f for f in detected_faces if f.det_score >= settings.min_det_score]

    # 3. Muat Data Wajah Peserta Sesi (Roster)
    participants = db.query(SessionParticipant).filter(SessionParticipant.session_id == session_id).all()
    participant_ids = [p.student_id for p in participants]
    
    registered_data = []
    for pid in participant_ids:
        embs = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == pid).all()
        if embs:
            registered_data.append({
                "student_id": pid,
                "embeddings": [e.embedding for e in embs]
            })

    # 4. Pencocokan Wajah (Matching)
    detected_embeddings = [f.normed_embedding for f in valid_faces]
    matches, unmatched = match_faces_hungarian(detected_embeddings, registered_data, settings.match_threshold)

    # 5. Simpan Hasil ke Database (Transaksi)
    # Simpan File Fisik
    os.makedirs(settings.storage_dir, exist_ok=True)
    img_path = os.path.join(settings.storage_dir, f"{client_capture_id}.jpg")
    with open(img_path, "wb") as f:
        f.write(content)

    # Simpan Capture
    sess.capture_count += 1
    new_capture = Capture(
        session_id=session_id, capture_no=sess.capture_count,
        client_capture_id=client_capture_id, image_path=img_path,
        image_width=img_w, image_height=img_h
    )
    db.add(new_capture)
    db.commit()
    db.refresh(new_capture)

    # Simpan Wajah & Kehadiran (Merge-Max)
    for match in matches:
        idx = match['detected_index']
        face_data = valid_faces[idx]
        bbox = face_data.bbox
        
        # Simpan Kotak Wajah (Bbox)
        cf = CaptureFace(
            capture_id=new_capture.id, bbox_x=bbox[0], bbox_y=bbox[1],
            bbox_w=bbox[2]-bbox[0], bbox_h=bbox[3]-bbox[1],
            det_score=float(face_data.det_score), student_id=match['student_id'],
            match_score=match['score'], status='identified'
        )
        db.add(cf)

        # Upsert Kehadiran (Merge Max Score)
        att = db.query(Attendance).filter(Attendance.session_id == session_id, Attendance.student_id == match['student_id']).first()
        if not att:
            db.add(Attendance(session_id=session_id, student_id=match['student_id'], status='hadir', match_score=match['score'], method='auto'))
        elif att.match_score is None or match['score'] > att.match_score:
            att.match_score = match['score']

    # Simpan Kotak Wajah Tidak Dikenal (Unknown)
    for idx in unmatched:
        bbox = valid_faces[idx].bbox
        cf = CaptureFace(
            capture_id=new_capture.id, bbox_x=bbox[0], bbox_y=bbox[1],
            bbox_w=bbox[2]-bbox[0], bbox_h=bbox[3]-bbox[1],
            det_score=float(valid_faces[idx].det_score), status='unknown'
        )
        db.add(cf)

    db.commit()
    return {"message": "Pengenalan selesai", "capture_id": new_capture.id, "matches_count": len(matches), "unknown_count": len(unmatched)}

@router.post("/attendance/confirm")
def confirm_attendance(session_id: int, student_id: int, db: Session = Depends(get_db)):
    """Konfirmasi kehadiran manual oleh dosen untuk wajah yang tidak dikenali."""
    att = db.query(Attendance).filter(Attendance.session_id == session_id, Attendance.student_id == student_id).first()
    if not att:
        db.add(Attendance(session_id=session_id, student_id=student_id, status='hadir', method='manual'))
        db.commit()
    return {"message": "Kehadiran manual berhasil dicatat"}