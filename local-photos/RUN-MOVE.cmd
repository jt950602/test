@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo === MOVE into C:\Local structure ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Organize-LocalPhotos.ps1" -Apply
echo.
pause
