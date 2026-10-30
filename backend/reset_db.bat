@echo off
cd /d "%~dp0"
echo Mereset database presensi...
.\.venv\Scripts\python.exe reset_db.py
pause
