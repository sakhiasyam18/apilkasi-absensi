from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List
import re
from app.database import get_db
from app.models import Student, ClassStudent, Class
from app.schemas import StudentResponse, StudentLookupResponse, ClassInfo
from app.errors import AppError

router = APIRouter(tags=["students"])

@router.get("/students/lookup", response_model=StudentLookupResponse)
def lookup_student(nim: str, db: Session = Depends(get_db)):
    # Validasi format NIM
    if not re.match(r'^\d{12}$', nim.strip()):
        raise AppError(code="validation_error", message="Format NIM tidak valid", status_code=422)
        
    # Cari mahasiswa di database
    student = db.query(Student).filter(Student.nim == nim.strip()).first()
    if not student:
        raise AppError(code="student_not_found", message="NIM belum terdaftar di kelas manapun. Hubungi dosen.", status_code=404)
        
    # Cari kelas yang diikuti mahasiswa ini
    classes = db.query(Class).join(ClassStudent).filter(ClassStudent.student_id == student.id).all()
    
    return StudentLookupResponse(
        id=student.id,
        nim=student.nim,
        full_name=student.full_name,
        has_faces=bool(student.has_faces),
        classes=[ClassInfo.model_validate(c) for c in classes]
    )