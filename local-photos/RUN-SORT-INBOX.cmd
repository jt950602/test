@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Re-sort only C:\Local\00_inbox ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Organize-LocalPhotos.ps1" -InboxOnly
echo.
echo If files remain, send C:\Local\00_inbox\_list.txt
echo Log: C:\Local\_organize-log.txt
echo.
pause
