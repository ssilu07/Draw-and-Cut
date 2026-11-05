@echo off
setlocal
cd /d "%~dp0"

echo ==================================================
echo   Draw ^& Cut - 1-Click Automated Release
echo ==================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\release.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Release script failed with exit code %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Release process finished successfully.
pause
