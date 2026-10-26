@echo off
cd /d "%~dp0"
echo Menjalankan Backend FastAPI Presensi Wajah...
call .venv\Scripts\activate.bat
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause
