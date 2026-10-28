@echo off
title Portable AI - Setup
color 0E

echo ===================================================
echo     PORTABLE AI - USB SETUP
echo ===================================================
echo.
echo  This will download and configure AI models onto
echo  your USB drive. You'll get to CHOOSE which models
echo  to install from a curated list.
echo.
echo   - 6 preset models (uncensored + standard)
echo   - Custom model support (bring your own GGUF)
echo   - Minimum USB space: 8 GB (16 GB recommended)
echo.
echo  Make sure you have a good internet connection!
echo.
pause

:: Run the PowerShell setup script from the same folder as this bat file
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=powershell"
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-core.ps1"
set "SETUP_EXIT=%ERRORLEVEL%"

echo.
echo ===================================================
if not "%SETUP_EXIT%"=="0" goto :SetupFailed

echo     SETUP COMPLETE! You're ready to go!
echo ===================================================
echo.
echo  To start: double-click start-fast-chat.bat
echo.
pause
exit /b 0

:SetupFailed
echo     SETUP DID NOT COMPLETE
echo ===================================================
echo.
echo  Setup was cancelled, or a download / model import failed.
echo  Do not start Fast Chat yet: it will not find a usable model.
echo  Read the errors above, fix the connection or disk issue,
echo  then run install.bat again. Completed downloads are skipped.
echo.
pause
exit /b %SETUP_EXIT%
