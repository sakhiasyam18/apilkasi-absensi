from fastapi import APIRouter, Depends, status, UploadFile, File, Form, Query
from sqlalchemy.orm import Session
from typing import List
import re
import numpy as np

from app.database import get_db
from app.models import Student, ClassStudent, Class, FaceEmbedding
from app.schemas import StudentResponse, StudentLookupResponse, ClassInfo
from app.errors import AppError
from app.config import settings
from app.services.image_utils import load_for_recognition
from app.services import face_engine

router = APIRouter(tags=["students"])

@router.get("/students/lookup", response_model=StudentLookupResponse)
def lookup_student(nim: str, db: Session = Depends(get_db)):
    if not re.match(r'^\d{12}$', nim.strip()):
        raise AppError(code="validation_error", message="Format NIM tidak valid", status_code=422)
        
    student = db.query(Student).filter(Student.nim == nim.strip()).first()
    if not student:
        raise AppError(code="student_not_found", message="NIM belum terdaftar di kelas manapun. Hubungi dosen.", status_code=404)
        
    classes = db.query(Class).join(ClassStudent).filter(ClassStudent.student_id == student.id).all()
    
    return StudentLookupResponse(
        id=student.id,
        nim=student.nim,
        full_name=student.full_name,
        has_faces=bool(student.has_faces),
        classes=[ClassInfo.model_validate(c) for c in classes]
    )

@router.post("/students/{id}/faces")
async def register_faces(
    id: int,
    overwrite: bool = Query(False),
    files: List[UploadFile] = File(...),
    pose_labels: str = Form(...),
    db: Session = Depends(get_db)
):
    student = db.query(Student).filter(Student.id == id).first()
    if not student:
        raise AppError(code="student_not_found", message="Mahasiswa tidak ditemukan", status_code=404)
    
    if student.has_faces and not overwrite:
        raise AppError(code="faces_already_registered", message="Wajah sudah terdaftar", status_code=409)
        
    if len(files) != settings.registration_photos:
        raise AppError(code="validation_error", message=f"Harus mengirim tepat {settings.registration_photos} foto", status_code=422)

    labels = [l.strip() for l in pose_labels.split(',')]
    if len(labels) != len(files):
        raise AppError(code="validation_error", message="Jumlah label pose tidak sama dengan jumlah file", status_code=422)

    embeddings = []
    errors = []
    
    for index, file in enumerate(files):
        content = await file.read()
        bgr_image, _ = load_for_recognition(content, settings.max_image_side)
        faces = face_engine.face_app_instance.analyze(bgr_image)
        
        # Buang deteksi wajah yang tidak memenuhi batas skor minimal
        valid_faces = [f for f in faces if f.det_score >= settings.reg_min_det_score]
        
        if len(valid_faces) == 0:
            errors.append({"index": index, "code": "no_face_detected"})
        elif len(valid_faces) > 1:
            errors.append({"index": index, "code": "multiple_faces"})
        else:
            embeddings.append((labels[index], valid_faces[0].det_score, valid_faces[0].normed_embedding))
            
    if errors:
        print(f"[REGISTRATION ERROR] Face detection errors: {errors}")
        raise AppError(code="face_detection_error", message="Terjadi kesalahan pada deteksi foto", status_code=422, details=errors)
        
    # Hitung rata-rata Cosine Similarity dari kelima wajah untuk memastikan itu orang yang sama
    sims = []
    for i in range(len(embeddings)):
        for j in range(i + 1, len(embeddings)):
            sim = np.dot(embeddings[i][2], embeddings[j][2])
            sims.append(sim)
    
    avg_sim = float(np.mean(sims))
    print(f"[REGISTRATION] Face self-similarity avg: {avg_sim:.4f} (threshold: {settings.reg_min_self_similarity})")
    if avg_sim < settings.reg_min_self_similarity:
        raise AppError(code="inconsistent_faces", message="5 foto tampak bukan orang yang sama", status_code=422)
        
    # Jika lolos validasi, simpan ke database
    if overwrite:
        db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student.id).delete()
        
    for label, score, emb in embeddings:
        db_emb = FaceEmbedding(
            student_id=student.id,
            pose_label=label,
            embedding=emb.tobytes(), # Simpan numpy array float32 sebagai data biner
            det_score=float(score)
        )
        db.add(db_emb)
        
    student.has_faces = 1
    db.commit()
    
    return {
        "student_id": student.id,
        "embeddings_saved": len(embeddings),
        "has_faces": True
    }