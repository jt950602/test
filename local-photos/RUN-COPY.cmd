@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo === COPY into C:\Local structure (sources stay) ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Organize-LocalPhotos.ps1" -Apply -Copy
echo.
pause
