@echo off
rem One-click installer for the Hackerring backend. Double-click to run.
rem Installs Python packages, FFmpeg tools, and all model downloads, so the
rem first server start is fast. Safe to re-run: every step skips what is
rem already present. After this, double-click START.bat for the full
rem backend + frontend startup (or run-api.bat for the API alone).
setlocal EnableExtensions
cd /d "%~dp0"

where python >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python 3.11 or newer was not found on PATH.
  echo Install it from https://www.python.org/downloads/ and tick "Add python.exe to PATH".
  pause
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo [1/5] Creating the virtual environment...
  python -m venv .venv
  if errorlevel 1 (
    echo ERROR: could not create .venv.
    pause
    exit /b 1
  )
) else (
  echo [1/5] Virtual environment already present, skipping.
)

echo [2/5] Installing Python packages (skips what is already satisfied)...
".venv\Scripts\python.exe" -m pip install --upgrade pip
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 (
  echo ERROR: dependency install failed. Check the lines above.
  pause
  exit /b 1
)
".venv\Scripts\python.exe" -m pip install -e ".[server,local,test]"
if errorlevel 1 (
  echo ERROR: optional server install failed. Check the lines above.
  pause
  exit /b 1
)

echo [3/5] Checking ffmpeg and ffprobe...
where ffmpeg >nul 2>nul
if errorlevel 1 goto install_ffmpeg
where ffprobe >nul 2>nul
if errorlevel 1 goto install_ffmpeg
echo        ffmpeg and ffprobe are on PATH.
goto fetch_models

:install_ffmpeg
echo        Trying the platform package manager (needs network)...
where winget >nul 2>nul
if errorlevel 1 goto try_choco
winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements --disable-interactivity
goto check_ffmpeg
:try_choco
where choco >nul 2>nul
if errorlevel 1 goto try_scoop
choco install ffmpeg -y --no-progress
goto check_ffmpeg
:try_scoop
where scoop >nul 2>nul
if errorlevel 1 goto no_ffmpeg
scoop install ffmpeg
goto check_ffmpeg
:check_ffmpeg
where ffmpeg >nul 2>nul
if errorlevel 1 goto no_ffmpeg
where ffprobe >nul 2>nul
if errorlevel 1 goto no_ffmpeg
echo        Installed. Open a NEW terminal to refresh PATH, or just run run-api.bat.
goto fetch_models
:no_ffmpeg
echo        Could not install automatically. Install FFmpeg yourself from
echo        https://www.gyan.dev/ffmpeg/builds/ and add its bin folder to PATH,
echo        then re-run this script. The server also retries at startup.
pause
exit /b 1

:fetch_models
if not exist ".env" (
  if exist ".env.example" (
    echo        Creating .env from the template so model settings apply; add your AGNES_API_KEY inside it for live AI.
    copy /y ".env.example" ".env" >nul
  )
)
echo [4/5] Downloading model weights (skips what is already cached)...
".venv\Scripts\python.exe" scripts\fetch_models.py
if errorlevel 1 (
  echo ERROR: model download failed. Check your network and re-run.
  pause
  exit /b 1
)

echo [5/5] Verifying the installed stack imports...
".venv\Scripts\python.exe" -c "import uvicorn, fastapi, faster_whisper, transformers, torch; import backend.server_loop; print('stack ok')"
if errorlevel 1 (
  echo ERROR: stack verification failed. Re-run this script; if it persists, read the lines above.
  pause
  exit /b 1
)

echo.
echo Done. Double-click START.bat for the full startup (backend + site),
echo or run-api.bat for the API alone.
echo Docs: http://localhost:8000/docs   Health: http://localhost:8000/health
pause
