from fastapi import FastAPI
from contextlib import asynccontextmanager
from fastapi.exceptions import RequestValidationError
from app.database import engine, Base
from app.errors import AppError, app_error_handler, validation_exception_handler
from app.routers import students, classes, sessions, attendance, points

# Import semua router yang sudah kita buat
from app.routers import students, classes, sessions

from app.config import settings
from app.services import face_engine

@asynccontextmanager
async def lifespan(app: FastAPI):
    face_engine.face_app_instance = face_engine.FaceEngine(
        model_name=settings.model_name, 
        det_size=settings.det_size
    )
    yield

Base.metadata.create_all(bind=engine)

app = FastAPI(title="API Presensi Wajah", lifespan=lifespan)

app.add_exception_handler(AppError, app_error_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)

# Daftarkan ketiga router ke FastAPI
app.include_router(classes.router)
app.include_router(students.router)
app.include_router(sessions.router)
app.include_router(attendance.router)
app.include_router(points.router)

@app.get("/health")
def health_check():
    is_loaded = face_engine.face_app_instance is not None
    return {"status": "ok", "model_loaded": is_loaded}