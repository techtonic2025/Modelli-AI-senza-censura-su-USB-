@echo off
title Portable AI - Faster Model Loading On This PC
color 0E

echo ===================================================
echo     FASTER MODEL LOADING ON THIS PC (OPTIONAL)
echo ===================================================
echo.
echo  Models load slowly from a USB drive (30-60 s on the
echo  first message). This option keeps a COPY of the AI
echo  models on THIS computer's disk so they load in ~1 s.
echo.
echo  PRIVACY - read before saying yes:
echo   - The copy stays on this PC: anyone using it can see
echo     which AI models you used (names and system prompt).
echo   - Your conversations are NOT copied: they stay on
echo     the USB drive only.
echo   - It uses as much disk space as your models.
echo   - Only for YOUR OWN computers. Not on shared/work PCs.
echo.
echo  The copy is made the next time you run start-fast-chat.bat
echo  and is kept in sync with the USB drive automatically.
echo  Remove it any time with clear-pc-cache.bat
echo.

choice /c YN /m " Enable the model copy on this PC (%COMPUTERNAME%)?"
if errorlevel 2 (
    echo.
    echo  Nothing changed. Models keep loading from the USB drive.
    echo.
    pause
    exit /b 0
)

>"%~dp0..\Shared\config\pc-cache-%COMPUTERNAME%.txt" echo yes
echo.
echo [OK] Enabled for this PC. Start the chat with start-fast-chat.bat
echo.
pause
