from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from app.database import engine, Base
from app.errors import AppError, app_error_handler, validation_exception_handler
from app.routers import students

# Generate tabel database SQLite
Base.metadata.create_all(bind=engine)

app = FastAPI(title="API Presensi Wajah")

# Daftarkan penanganan error khusus
app.add_exception_handler(AppError, app_error_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)

# Daftarkan rute API
app.include_router(students.router)

@app.get("/health")
def health_check():
    # model_loaded sementara false, akan kita ubah di Fase 2 nanti
    return {"status": "ok", "model_loaded": False}