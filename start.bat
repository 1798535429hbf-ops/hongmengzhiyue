@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1" %*
set START_EXIT_CODE=%ERRORLEVEL%

echo.
if not "%CI%"=="true" pause
exit /b %START_EXIT_CODE%
