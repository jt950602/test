@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Copy (not move) into structure...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Organize-LocalPhotos.ps1" -Copy
echo.
pause
