@echo off
rem One-click local server for the Hackerring backend. Double-click to run.
rem Loopback only (http://localhost:PORT) -- the backend has no login, so it
rem is never exposed to the network. First run installs and downloads more.
setlocal EnableExtensions
cd /d "%~dp0"
if "%~1"=="" (set PORT=8000) else (set PORT=%~1)

where python >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python 3.11 or newer was not found on PATH.
  echo Install it from https://www.python.org/downloads/ and tick "Add python.exe to PATH".
  pause
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo Creating the virtual environment (one time only)...
  python -m venv .venv
  if errorlevel 1 (
    echo ERROR: could not create .venv.
    pause
    exit /b 1
  )
  echo Installing dependencies (one time only, takes several minutes)...
  ".venv\Scripts\python.exe" -m pip install --upgrade pip
  ".venv\Scripts\python.exe" -m pip install -r requirements.txt
  if errorlevel 1 (
    echo ERROR: dependency install failed. Check the lines above.
    pause
    exit /b 1
  )
  ".venv\Scripts\python.exe" -m pip install -e ".[server,test]"
  if errorlevel 1 (
    echo ERROR: optional server install failed. Check the lines above.
    pause
    exit /b 1
  )
)

if not exist ".env" (
  echo ERROR: .env was not found next to this script.
  echo Copy .env.example to .env and set AGNES_API_KEY inside it.
  pause
  exit /b 1
)

where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo NOTE: ffmpeg/ffprobe are not on PATH. Startup will try to install
  echo them automatically, otherwise it exits telling you what is missing.
) else (
  where ffprobe >nul 2>nul
  if errorlevel 1 (
    echo NOTE: ffprobe was not found next to ffmpeg. Startup will try to
    echo install it automatically, otherwise it exits telling you what is missing.
  )
)

echo.
echo Starting the Hackerring API on http://localhost:%PORT% ...
echo   Docs:   http://localhost:%PORT%/docs
echo   Health: http://localhost:%PORT%/health
echo Press Ctrl+C to stop.
echo.
".venv\Scripts\python.exe" -m uvicorn backend.main:app --host 127.0.0.1 --port %PORT% --env-file .env
echo.
echo Server stopped.
pause
