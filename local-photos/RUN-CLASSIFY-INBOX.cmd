@echo off
chcp 65001 >nul
cd /d "%~dp0"
python -m pip install -r requirements.txt
python classify_photos.py --root "C:\Local" --inbox-only --apply
if exist "%USERPROFILE%\Desktop\local-classify-log.txt" (
  start notepad "%USERPROFILE%\Desktop\local-classify-log.txt"
)
pause
