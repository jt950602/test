@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Installing Python deps (first run)...
python -m pip install -r requirements.txt
if errorlevel 1 (
  echo FAILED: pip install. Is Python on PATH?
  pause
  exit /b 1
)
echo.
echo PREVIEW only - no files moved.
python classify_photos.py --root "C:\Local" --preview
echo.
echo Log: classify-log.txt  and  Desktop\local-classify-log.txt
pause
