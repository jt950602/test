@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo === Re-sort C:\Local\00_inbox into service folders ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Organize-LocalPhotos.ps1" -InboxOnly -Apply
echo.
echo If files remain in 00_inbox, open:
echo   C:\Local\00_inbox\_list.txt
echo and send the list to the assistant.
echo.
pause
