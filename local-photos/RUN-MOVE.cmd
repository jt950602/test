@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%Organize-LocalPhotos.ps1"
set "LOG1=%SCRIPT_DIR%organize-log.txt"
set "LOG2=%USERPROFILE%\Desktop\local-organize-log.txt"
set "LOG3=C:\Local\_organize-log.txt"

echo ==== LOCAL organizer launcher ==== > "%LOG1%"
echo Time: %DATE% %TIME%>> "%LOG1%"
echo Script dir: %SCRIPT_DIR%>> "%LOG1%"
echo.>> "%LOG1%"

if not exist "%PS1%" (
  echo ERROR: Organize-LocalPhotos.ps1 not found in %SCRIPT_DIR%>> "%LOG1%"
  echo ERROR: Organize-LocalPhotos.ps1 not found next to this .cmd
  copy /Y "%LOG1%" "%LOG2%" >nul 2>&1
  notepad "%LOG1%"
  pause
  exit /b 1
)

echo PS1 found: %PS1%>> "%LOG1%"

if exist "C:\Local\" (
  echo C:\Local EXISTS>> "%LOG1%"
  dir /s /b "C:\Local\*.jpg" 2>nul | find /c /v "" >> "%LOG1%"
  echo jpg paths counted above>> "%LOG1%"
) else (
  echo C:\Local DOES NOT EXIST>> "%LOG1%"
)

echo.>> "%LOG1%"
echo Running PowerShell...>> "%LOG1%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { & '%PS1%' -Root 'C:\Local' *>> '%LOG1%' 2>&1; Write-Output ('EXIT_CODE=' + $LASTEXITCODE) } catch { $_ | Out-String | Write-Output; Write-Output ('EXCEPTION=' + $_.Exception.Message) }"

echo.>> "%LOG1%"
echo PowerShell finished.>> "%LOG1%"

if exist "C:\Local\" (
  mkdir "C:\Local" 2>nul
  copy /Y "%LOG1%" "%LOG3%" >nul 2>&1
)
copy /Y "%LOG1%" "%LOG2%" >nul 2>&1

echo.
echo ==============================
echo Log saved to:
echo   %LOG1%
echo   %LOG2%
if exist "%LOG3%" echo   %LOG3%
echo ==============================
echo.
notepad "%LOG1%"
pause
