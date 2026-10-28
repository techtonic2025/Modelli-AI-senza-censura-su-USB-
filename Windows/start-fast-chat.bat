@echo off
title Portable AI - Fast Web Chat
color 0B

echo ===================================================
echo     Portable AI - Fast Web Chat Mode
echo ===================================================
echo.
echo  Launches the AI engine + browser chat UI.
echo  All chats auto-save to the USB drive.
echo.

:: Set paths to USB Shared Folder
set "OLLAMA_MODELS=%~dp0..\Shared\models\ollama_data"
set "OLLAMA_ORIGINS=*"
:: Own port, so a system-wide Ollama install (11434) never gets in the way
set "OLLAMA_HOST=127.0.0.1:11435"
:: Speed/RAM: flash attention; keep the model loaded
:: for 30 min (reloading from a USB drive is slow); never prune model blobs
set "OLLAMA_FLASH_ATTENTION=1"
set "OLLAMA_KEEP_ALIVE=30m"
set "OLLAMA_NOPRUNE=1"

:: -------------------------------------------------------
:: Find Python: prefer portable USB copy, then system
:: -------------------------------------------------------
set "PYTHON_CMD="

:: Check for portable Python bundled on USB
if exist "%~dp0..\Shared\python\python.exe" (
    set "PYTHON_CMD=%~dp0..\Shared\python\python.exe"
    echo [OK] Using portable Python from USB drive.
    goto :PythonReady
)

:: Check for system-installed Python (and that it actually works:
:: broken installs fail on "import ctypes")
python -c "import ctypes, json, http.server" >nul 2>&1
if %errorlevel%==0 (
    set "PYTHON_CMD=python"
    echo [OK] Using system Python.
    goto :PythonReady
)

:: Python not found anywhere
echo ===================================================
echo  ERROR: Python not found!
echo ===================================================
echo.
echo  Downloading portable Python to USB drive...
echo  (This only happens once, ~11MB download)
echo.

curl.exe -L --fail --ssl-no-revoke "https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip" -o "%~dp0..\Shared\python-embed.zip"
if %errorlevel% neq 0 (
    echo Download failed. Please check your internet connection.
    pause
    exit
)

echo Extracting...
powershell -Command "Expand-Archive -Path '%~dp0..\Shared\python-embed.zip' -DestinationPath '%~dp0..\Shared\python' -Force"
del "%~dp0..\Shared\python-embed.zip" >nul 2>&1

if exist "%~dp0..\Shared\python\python.exe" (
    set "PYTHON_CMD=%~dp0..\Shared\python\python.exe"
    echo [OK] Portable Python installed on USB successfully!
) else (
    echo Failed to extract Python. Please try again.
    pause
    exit
)

:: -------------------------------------------------------
:: Start Ollama Engine
:: -------------------------------------------------------
:PythonReady

if not exist "%~dp0..\Shared\bin\ollama-windows.exe" (
    echo.
    echo ===================================================
    echo  ERROR: Ollama Engine Not Found!
    echo ===================================================
    echo.
    echo  It looks like the AI engine hasn't been set up yet.
    echo  Please double-click "install.bat" in the Windows 
    echo  folder first to safely download the components!
    echo.
    pause
    exit
)

:: Check if Ollama is already running
curl.exe -s http://%OLLAMA_HOST%/api/tags >nul 2>&1
if %errorlevel%==0 (
    echo [OK] Ollama engine is already running!
    goto :StartChat
)

call :SetupPcCache

echo Starting Ollama Engine...
start /b "" "%~dp0..\Shared\bin\ollama-windows.exe" serve

echo Waiting for engine to initialize...
set /a WAIT_SECS=0
:WaitLoop
timeout /t 1 /nobreak >nul
curl.exe -s http://%OLLAMA_HOST%/api/tags >nul 2>&1
if %errorlevel%==0 goto :EngineOnline
set /a WAIT_SECS+=1
if %WAIT_SECS% lss 90 goto :WaitLoop
echo.
echo ===================================================
echo  ERROR: The AI engine did not start in 90 seconds.
echo ===================================================
echo.
echo  Read the messages above. If you see "runtime" or "panic"
echo  errors the engine files are damaged: run install.bat again.
echo.
taskkill /f /im ollama-windows.exe >nul 2>&1
pause
exit /b 1

:EngineOnline
echo [OK] Engine is online!

:: -------------------------------------------------------
:: Start Chat Server
:: -------------------------------------------------------
:StartChat
echo.
echo ===================================================
echo  AI ENGINE IS RUNNING
echo  Chat UI opening at: http://localhost:3333
echo  Close this window to shut down everything.
echo ===================================================
echo.

%PYTHON_CMD% "%~dp0..\Shared\chat_server.py"

echo Shutting down...
taskkill /f /im ollama-windows.exe >nul 2>&1
echo Done. Goodbye!
pause
exit /b 0

:: -------------------------------------------------------
:: Optional PC cache (OFF by default, nothing is written to
:: the PC). Turned on per computer with enable-pc-cache.bat:
:: a copy of the models is kept on this computer's internal
:: disk so they load in ~1 s instead of being read from USB.
:: Undo with clear-pc-cache.bat.
:: -------------------------------------------------------
:SetupPcCache
set "USB_MODELS=%~dp0..\Shared\models\ollama_data"
set "PC_CACHE=%LOCALAPPDATA%\PortableAI\ollama_data"
set "CACHE_CHOICE=%~dp0..\Shared\config\pc-cache-%COMPUTERNAME%.txt"
if not exist "%USB_MODELS%\blobs" exit /b 0
if not exist "%CACHE_CHOICE%" exit /b 0

findstr /i /x "yes" "%CACHE_CHOICE%" >nul 2>&1
if errorlevel 1 exit /b 0

echo Syncing models to this PC's disk (slow only the first time)...
:: /MIR keeps the PC copy identical to the USB; /FFT tolerates exFAT/FAT timestamps
robocopy "%USB_MODELS%" "%PC_CACHE%" /MIR /FFT /R:1 /W:1 /NFL /NDL /NJH /NJS >nul
if errorlevel 8 (
    echo [!] Could not copy the models to this PC ^(disk full?^). Loading from USB.
    exit /b 0
)
set "OLLAMA_MODELS=%PC_CACHE%"
echo [OK] Models will load from this PC's disk.
exit /b 0
