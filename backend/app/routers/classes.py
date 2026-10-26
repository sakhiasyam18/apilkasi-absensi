import csv
import io
import re
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, UploadFile, File, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Class, Student, ClassStudent
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

def _process_roster_data(cls: Class, entries: List[Dict[str, Any]], db: Session) -> Dict[str, Any]:
    # Ambil ID mahasiswa yang sudah ada di kelas ini
    existing_class_student_ids = {
        r[0] for r in db.query(ClassStudent.student_id).filter(ClassStudent.class_id == cls.id).all()
    }
    current_count = len(existing_class_student_ids)

    # Hitung perkiraan penambahan untuk cek kapasitas (class_full)
    seen_nims = set()
    to_add_count = 0
    for item in entries:
        nim = item["nim"].strip()
        name = item["full_name"].strip()
        if re.match(r'^\d{12}$', nim) and name and nim not in seen_nims:
            seen_nims.add(nim)
            st = db.query(Student).filter(Student.nim == nim).first()
            if not st or st.id not in existing_class_student_ids:
                to_add_count += 1

    if current_count + to_add_count > settings.max_students_per_class:
        raise AppError(
            "class_full",
            f"Jumlah mahasiswa melebihi batas {settings.max_students_per_class} per kelas.",
            409
        )

    added = 0
    linked = 0
    skipped = 0
    errors = []
    warnings = []

    for item in entries:
        row_idx = item["row"]
        nim = item["nim"].strip()
        name = item["full_name"].strip()

        if not re.match(r'^\d{12}$', nim) or not name:
            errors.append({"row": row_idx, "nim": nim, "code": "validation_error"})
            continue

        student = db.query(Student).filter(Student.nim == nim).first()
        if not student:
            # Mahasiswa baru, buat data profil lalu tautkan ke kelas
            student = Student(nim=nim, full_name=name, has_faces=0)
            db.add(student)
            db.flush()

            db.add(ClassStudent(class_id=cls.id, student_id=student.id))
            existing_class_student_ids.add(student.id)
            added += 1
        else:
            # Mahasiswa sudah ada di database
            if student.id in existing_class_student_ids:
                skipped += 1
            else:
                db.add(ClassStudent(class_id=cls.id, student_id=student.id))
                existing_class_student_ids.add(student.id)
                linked += 1

            # Beri peringatan jika nama yang diinput berbeda dengan nama di database (BR-15)
            if student.full_name.strip().lower() != name.lower():
                warnings.append({
                    "row": row_idx,
                    "nim": nim,
                    "code": "name_mismatch",
                    "existing_name": student.full_name
                })

    db.commit()
    return {
        "added": added,
        "linked_existing": linked,
        "skipped": skipped,
        "errors": errors,
        "warnings": warnings
    }

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
        faces_count = (
            db.query(Student)
            .join(ClassStudent, ClassStudent.student_id == Student.id)
            .filter(ClassStudent.class_id == c.id, Student.has_faces == 1)
            .count()
        )
        result.append({
            "id": c.id,
            "name": c.name,
            "code": c.code,
            "student_count": count,
            "faces_registered_count": faces_count
        })
    return result

@router.get("/classes/{id}")
def get_class_detail(id: int, db: Session = Depends(get_db)):
    cls = db.query(Class).filter(Class.id == id).first()
    if not cls:
        raise AppError("class_not_found", "Kelas tidak ditemukan", 404)
    
    students = (
        db.query(Student)
        .join(ClassStudent, ClassStudent.student_id == Student.id)
        .filter(ClassStudent.class_id == id)
        .order_by(Student.nim.asc())
        .all()
    )
    
    return {
        "id": cls.id,
        "name": cls.name,
        "code": cls.code,
        "student_count": len(students),
        "students": [
            {
                "id": s.id,
                "nim": s.nim,
                "full_name": s.full_name,
                "has_faces": bool(s.has_faces)
            }
            for s in students
        ]
    }

@router.post("/classes/{id}/students")
def add_students_to_class(id: int, roster: RosterInput, db: Session = Depends(get_db)):
    cls = db.query(Class).filter(Class.id == id).first()
    if not cls:
        raise AppError("class_not_found", "Kelas tidak ditemukan", 404)

    entries = [
        {"row": idx, "nim": st.nim, "full_name": st.full_name}
        for idx, st in enumerate(roster.students, start=1)
    ]
    return _process_roster_data(cls, entries, db)

@router.post("/classes/{id}/students/import")
async def import_students_csv(id: int, file: UploadFile = File(...), db: Session = Depends(get_db)):
    cls = db.query(Class).filter(Class.id == id).first()
    if not cls:
        raise AppError("class_not_found", "Kelas tidak ditemukan", 404)

    contents = await file.read()
    if not contents:
        raise AppError("invalid_csv", "File CSV kosong", 400)

    try:
        text = contents.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise AppError("invalid_csv", "Encoding file harus UTF-8", 400)

    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        raise AppError("invalid_csv", "File CSV tidak memiliki data", 400)

    first_line = lines[0]
    delimiter = ";" if first_line.count(";") > first_line.count(",") else ","

    reader = csv.reader(io.StringIO(text), delimiter=delimiter)
    try:
        header = next(reader)
    except StopIteration:
        raise AppError("invalid_csv", "Header CSV tidak ditemukan", 400)

    header_clean = [col.strip().lower() for col in header]

    nim_idx = -1
    name_idx = -1
    for idx, col in enumerate(header_clean):
        if col == "nim":
            nim_idx = idx
        elif col in ["nama", "full_name", "nama_lengkap"]:
            name_idx = idx

    if nim_idx == -1 or name_idx == -1:
        raise AppError(
            "invalid_csv",
            "Header CSV wajib memiliki kolom 'nim' dan salah satu dari 'nama', 'full_name', atau 'nama_lengkap'",
            400
        )

    data_rows = []
    for row in reader:
        if not any(field.strip() for field in row):
            continue
        data_rows.append(row)

    if not data_rows:
        raise AppError("invalid_csv", "File CSV tidak memiliki baris data mahasiswa", 400)

    if len(data_rows) > settings.max_import_rows:
        raise AppError(
            "invalid_csv",
            f"Jumlah baris ({len(data_rows)}) melebihi batas maksimal {settings.max_import_rows}",
            400
        )

    entries = []
    for row_idx, row in enumerate(data_rows, start=1):
        nim = row[nim_idx].strip() if len(row) > nim_idx else ""
        name = row[name_idx].strip() if len(row) > name_idx else ""
        entries.append({"row": row_idx, "nim": nim, "full_name": name})

    return _process_roster_data(cls, entries, db)