from fastapi import FastAPI
from contextlib import asynccontextmanager
from fastapi.exceptions import RequestValidationError
from app.database import engine, Base
from app.errors import AppError, app_error_handler, validation_exception_handler
from app.routers import students
from app.config import settings
from app.services import face_engine

# Load model AI saat server menyala
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Proses ini butuh internet di awal untuk download model buffalo_l (~300MB)
    face_engine.face_app_instance = face_engine.FaceEngine(
        model_name=settings.model_name, 
        det_size=settings.det_size
    )
    yield

Base.metadata.create_all(bind=engine)

app = FastAPI(title="API Presensi Wajah", lifespan=lifespan)

app.add_exception_handler(AppError, app_error_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)

app.include_router(students.router)

@app.get("/health")
def health_check():
    # Mengembalikan nilai True jika AI sudah siap digunakan
    is_loaded = face_engine.face_app_instance is not None
    return {"status": "ok", "model_loaded": is_loaded}