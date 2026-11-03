import hashlib
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User
from app.schemas import UserResponse, LoginRequest, RegisterRequest
from app.errors import AppError

router = APIRouter(prefix="/auth", tags=["auth"])

def _hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    email = req.email.strip().lower()
    if not email:
        raise AppError("validation_error", "Email tidak boleh kosong", 422)
    if not req.password:
        raise AppError("validation_error", "Password tidak boleh kosong", 422)
    if not req.full_name.strip():
        raise AppError("validation_error", "Nama lengkap tidak boleh kosong", 422)

    existing = db.query(User).filter(User.email == email).first()
    if existing:
        raise AppError("user_exists", "Email sudah terdaftar", 409)

    user = User(
        email=email,
        password_hash=_hash_password(req.password),
        full_name=req.full_name.strip(),
        identifier=req.identifier.strip() if req.identifier else None,
        role=req.role.strip().lower() if req.role else "dosen",
        program_study=req.program_study.strip() if req.program_study else None,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

@router.post("/login", response_model=UserResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    email = req.email.strip().lower()
    user = db.query(User).filter(User.email == email).first()

    # Convenience check: if DB is fresh and user logs in as default Ashar Pakawaru dosen,
    # auto-provision this verified dosen account so the user can immediately test!
    if not user and email == "ashar.pakawaru@um.ac.id":
        user = User(
            email="ashar.pakawaru@um.ac.id",
            password_hash=_hash_password(req.password if req.password else "password123"),
            full_name="Dr. Ir. Ashar Pakawaru, S.T., M.T.",
            identifier="19750815 200212 1 002",
            role="dosen",
            program_study="S1 Teknik Informatika - Universitas Negeri Malang"
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    if not user:
        raise AppError("invalid_credentials", "Email atau password salah", 401)

    if user.password_hash != _hash_password(req.password):
        raise AppError("invalid_credentials", "Email atau password salah", 401)

    return user

@router.get("/users", response_model=List[UserResponse])
def get_users(db: Session = Depends(get_db)):
    return db.query(User).all()
