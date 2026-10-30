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
    
    for index, file in enumerate(files):
        content = await file.read()
        bgr_image, _ = load_for_recognition(content, settings.max_image_side)
        
        # 1. Coba deteksi orientasi normal
        faces = face_engine.face_app_instance.analyze(bgr_image)
        valid_faces = [f for f in faces if f.det_score >= 0.35]
        
        # 2. Jika tidak terdeteksi, coba otomatis rotasi (90°, 180°, 270°) jika sensor kamera HP menyimpan foto miring
        if len(valid_faces) == 0:
            for rot_k in [1, 2, 3]: # 90, 180, 270 derajat
                rotated_img = np.ascontiguousarray(np.rot90(bgr_image, rot_k))
                r_faces = face_engine.face_app_instance.analyze(rotated_img)
                r_valid = [f for f in r_faces if f.det_score >= 0.35]
                if len(r_valid) >= 1:
                    valid_faces = r_valid
                    print(f"[REGISTRATION AUTO-ROTATE] Sukses mendeteksi wajah pada foto {index+1} ({labels[index]}) dengan rotasi {rot_k * 90}°")
                    break

        # Ambil wajah terbesar jika ada beberapa deteksi kecil di latar belakang
        if len(valid_faces) >= 1:
            best_face = max(valid_faces, key=lambda f: (f.bbox[2]-f.bbox[0]) * (f.bbox[3]-f.bbox[1]))
            embeddings.append((labels[index], best_face.det_score, best_face.normed_embedding))
            print(f"[REGISTRATION SUCCESS] Foto {index+1} ({labels[index]}): Terdeteksi (score: {best_face.det_score:.3f})")
        else:
            print(f"[REGISTRATION SKIP] Foto {index+1} ({labels[index]}): Dilewati karena wajah tidak terdeteksi jelas.")

    # Fleksibel: Minimal 1 foto wajah berhasil terdeteksi sudah CUKUP untuk disimpan!
    if len(embeddings) == 0:
        raise AppError(
            code="no_face_detected",
            message="Wajah sama sekali tidak terdeteksi di foto. Pastikan kamera menghadap wajah dan pencahayaan tidak terlalu gelap.",
            status_code=422
        )

    # Simpan ke database (bila daftar ulang / sudah ada wajah, hapus embedding lama)
    if overwrite or student.has_faces:
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
    
    print(f"[REGISTRATION COMPLETE] Berhasil menyimpan {len(embeddings)} vektor wajah untuk mahasiswa ID {student.id} (NIM: {student.nim})!")
    return {
        "student_id": student.id,
        "embeddings_saved": len(embeddings),
        "has_faces": True
    }