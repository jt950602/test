@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo === Dry-run (preview) ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Organize-LocalPhotos.ps1"
echo.
echo If the plan looks OK, run one of:
echo   RUN-COPY.cmd     - copy into new folders (safe)
echo   RUN-MOVE.cmd     - move into new folders
echo.
pause
