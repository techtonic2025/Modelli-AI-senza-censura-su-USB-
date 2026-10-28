@echo off
title Portable AI - Remove PC Cache
color 0E

echo ===================================================
echo     PORTABLE AI - REMOVE MODEL COPY FROM THIS PC
echo ===================================================
echo.
echo  Deletes the copy of the AI models kept on this
echo  computer's disk (if any). The models on the USB
echo  drive are NOT touched. Models load from the USB drive
echo  again; re-enable with enable-pc-cache.bat.
echo.
pause

taskkill /f /im ollama-windows.exe >nul 2>&1
if exist "%LOCALAPPDATA%\PortableAI" (
    rmdir /s /q "%LOCALAPPDATA%\PortableAI"
    echo [OK] Removed %LOCALAPPDATA%\PortableAI
) else (
    echo  No copy found on this PC.
)
del "%~dp0..\Shared\config\pc-cache-%COMPUTERNAME%.txt" >nul 2>&1

echo.
echo Done.
pause
