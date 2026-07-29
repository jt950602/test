@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo Moving photos inside C:\Local into service folders...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Organize-LocalPhotos.ps1"
echo.
echo Log: C:\Local\_organize-log.txt
echo.
pause
