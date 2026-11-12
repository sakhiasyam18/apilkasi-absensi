@echo off
setlocal enabledelayedexpansion
title Server Backend SnapAttend V3
cd /d "%~dp0backend"

echo ========================================================
echo       MENJALANKAN SERVER BACKEND SNAPATTEND V3
echo ========================================================
echo.

:: Deteksi Otomatis IP Wi-Fi / Hotspot Laptop yang Aktif (Dinamis)
set "WIFI_IP="
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        echo %%b | findstr /v "169.254" >nul && set "WIFI_IP=%%b"
    )
)

echo Alamat URL Server untuk Aplikasi HP:
echo   [1] Mode USB Kabel : http://127.0.0.1:8000  (Selalu Tetap / Statis)
if defined WIFI_IP (
    echo   [2] Mode Wi-Fi     : http://!WIFI_IP!:8000  (Terdeteksi Otomatis!)
) else (
    echo   [2] Mode Wi-Fi     : http://[IP-LAPTOP]:8000 (Pastikan Wi-Fi terhubung)
)
echo ========================================================
echo Tips: Jika ganti Wi-Fi / Hotspot, masukkan Alamat Mode Wi-Fi
echo di atas ke menu Pengaturan Server (ikon gerigi) pada HP Anda.
echo ========================================================
echo.
call .venv\Scripts\activate.bat
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause
