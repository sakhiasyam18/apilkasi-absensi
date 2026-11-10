@echo off
title Server Backend SnapAttend V3
cd /d "%~dp0backend"
echo ========================================================
echo       MENJALANKAN SERVER BACKEND SNAPATTEND V3
echo ========================================================
echo Server aktif di http://0.0.0.0:8000
echo - Untuk USB  : Gunakan http://127.0.0.1:8000
echo - Untuk Wi-Fi: Gunakan http://192.168.***.***:8000
echo ========================================================
call .venv\Scripts\activate.bat
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause
