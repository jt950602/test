@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Installing Python deps if needed...
python -m pip install -r requirements.txt
if errorlevel 1 (
  echo FAILED: pip install. Is Python on PATH?
  pause
  exit /b 1
)
echo.
echo MOVE mode: photos will be relocated under C:\Local
python classify_photos.py --root "C:\Local" --apply
echo.
if exist "%USERPROFILE%\Desktop\local-classify-log.txt" (
  start notepad "%USERPROFILE%\Desktop\local-classify-log.txt"
)
pause
