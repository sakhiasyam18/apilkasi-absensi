from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import Student
from app.schemas import StudentCreate, StudentResponse
from app.errors import AppError

router = APIRouter(tags=["students"])

@router.post("/register", response_model=StudentResponse, status_code=status.HTTP_201_CREATED)
def register_student(student: StudentCreate, db: Session = Depends(get_db)):
    student.full_name = student.full_name.strip()
    if not student.full_name:
        raise AppError(code="validation_error", message="Nama tidak boleh kosong", status_code=422)

    existing = db.query(Student).filter(Student.nim == student.nim).first()
    if existing:
        raise AppError(code="nim_duplicate", message="NIM sudah terdaftar.", status_code=409)

    new_student = Student(nim=student.nim, full_name=student.full_name)
    db.add(new_student)
    db.commit()
    db.refresh(new_student)
    
    return new_student

@router.get("/students", response_model=List[StudentResponse])
def get_students(db: Session = Depends(get_db)):
    return db.query(Student).all()