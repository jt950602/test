@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Preview only - NO files will be moved.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Organize-LocalPhotos.ps1" -Preview
echo.
pause
