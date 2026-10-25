from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
import re

from app.database import get_db
from app.models import Class, Student, ClassStudent
from app.schemas import ClassInfo
from app.errors import AppError
from app.config import settings

router = APIRouter(tags=["classes"])

class ClassCreate(BaseModel):
    name: str
    code: Optional[str] = None

class StudentInput(BaseModel):
    nim: str
    full_name: str

class RosterInput(BaseModel):
    students: List[StudentInput]

@router.post("/classes", status_code=201)
def create_class(cls_input: ClassCreate, db: Session = Depends(get_db)):
    if not cls_input.name.strip():
        raise AppError("validation_error", "Nama kelas tidak boleh kosong", 422)
    new_cls = Class(name=cls_input.name.strip(), code=cls_input.code)
    db.add(new_cls)
    db.commit()
    db.refresh(new_cls)
    return {
        "id": new_cls.id, 
        "name": new_cls.name, 
        "code": new_cls.code, 
        "student_count": 0, 
        "max_students": settings.max_students_per_class
    }

@router.get("/classes")
def get_classes(db: Session = Depends(get_db)):
    classes = db.query(Class).all()
    result = []
    for c in classes:
        count = db.query(ClassStudent).filter(ClassStudent.class_id == c.id).count()
        result.append({"id": c.id, "name": c.name, "code": c.code, "student_count": count})
    return result

@router.post("/classes/{id}/students")
def add_students_to_class(id: int, roster: RosterInput, db: Session = Depends(get_db)):
    cls = db.query(Class).filter(Class.id == id).first()
    if not cls:
        raise AppError("class_not_found", "Kelas tidak ditemukan", 404)
        
    current_count = db.query(ClassStudent).filter(ClassStudent.class_id == id).count()
    if current_count + len(roster.students) > settings.max_students_per_class:
        raise AppError("class_full", f"Kelas sudah mencapai batas {settings.max_students_per_class} mahasiswa.", 409)

    added = linked = skipped = 0
    errors, warnings = [], []

    for idx, st in enumerate(roster.students, start=1):
        nim = st.nim.strip()
        name = st.full_name.strip()
        
        if not re.match(r'^\d{12}$', nim) or not name:
            errors.append({"row": idx, "nim": nim, "code": "validation_error"})
            continue
            
        student = db.query(Student).filter(Student.nim == nim).first()
        if not student:
            # Mahasiswa baru, buat profil lalu masukkan ke kelas
            student = Student(nim=nim, full_name=name)
            db.add(student)
            db.commit()
            db.refresh(student)
            
            db.add(ClassStudent(class_id=id, student_id=student.id))
            db.commit()
            added += 1
        else:
            # Mahasiswa sudah ada, cek apakah sudah di kelas ini
            is_linked = db.query(ClassStudent).filter(ClassStudent.class_id == id, ClassStudent.student_id == student.id).first()
            if is_linked:
                skipped += 1
            else:
                db.add(ClassStudent(class_id=id, student_id=student.id))
                db.commit()
                linked += 1
                
            # Beri peringatan jika nama yang diinput berbeda dengan nama di database
            if student.full_name.lower() != name.lower():
                warnings.append({"row": idx, "nim": nim, "code": "name_mismatch", "existing_name": student.full_name})
                
    return {"added": added, "linked_existing": linked, "skipped": skipped, "errors": errors, "warnings": warnings}