@echo off
chcp 65001 >nul
setlocal
set "OUT=%USERPROFILE%\Desktop\local-diag.txt"
echo ==== DIAG %DATE% %TIME% ==== > "%OUT%"
echo.>> "%OUT%"
echo C:\Local exists?>> "%OUT%"
if exist "C:\Local\" (echo YES>> "%OUT%") else (echo NO>> "%OUT%")
echo.>> "%OUT%"
echo Top of C:\Local:>> "%OUT%"
dir "C:\Local" >> "%OUT%" 2>&1
echo.>> "%OUT%"
echo First 50 media files:>> "%OUT%"
dir /s /b "C:\Local\*.jpg" "C:\Local\*.jpeg" "C:\Local\*.png" "C:\Local\*.mp4" "C:\Local\*.mov" 2>nul | more +0 | more +0
dir /s /b "C:\Local\*.jpg" 2>nul | more +1 | findstr /n "^" | findstr "^[1-9]: ^1[0-9]: ^2[0-9]: ^3[0-9]: ^4[0-9]: ^50:" >> "%OUT%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "if (Test-Path 'C:\Local') { Get-ChildItem 'C:\Local' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 50 -ExpandProperty FullName | Out-File -FilePath '%OUT%' -Append -Encoding utf8; 'COUNT=' + ((Get-ChildItem 'C:\Local' -Recurse -File -EA SilentlyContinue).Count) | Out-File '%OUT%' -Append -Encoding utf8 } else { 'NO C:\Local' | Out-File '%OUT%' -Append -Encoding utf8 }"
echo.>> "%OUT%"
echo Saved: %OUT%
notepad "%OUT%"
pause
