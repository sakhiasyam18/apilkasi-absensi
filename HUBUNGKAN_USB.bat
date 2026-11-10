@echo off
title Hubungkan USB Tunnel SnapAttend V3
echo ========================================================
echo       HUBUNGKAN PORT USB (ADB REVERSE TUNNEL)
echo ========================================================
where adb >nul 2>nul
if %errorlevel% equ 0 (
    adb reverse tcp:8000 tcp:8000
) else (
    if exist "D:\AndroidStudio\platform-tools\adb.exe" (
        "D:\AndroidStudio\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
    ) else (
        adb reverse tcp:8000 tcp:8000
    )
)
echo.
echo [BERHASIL] Port USB reverse tcp:8000 telah terhubung!
echo Di HP Anda: Buka Pengaturan Server -> Gunakan http://127.0.0.1:8000
echo ========================================================
pause
