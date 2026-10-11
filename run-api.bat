@echo off
rem Start the ContextGuard API on 127.0.0.1:8000. Self-contained: started by
rem START.bat, or double-clicked on its own.
setlocal EnableExtensions
cd /d "%~dp0"

where python >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python 3.11 or newer was not found on PATH.
  pause
  exit /b 1
)
if not exist ".venv\Scripts\python.exe" (
  echo [api] Creating the virtual environment, one time only...
  python -m venv .venv
  if errorlevel 1 (
    echo ERROR: could not create .venv.
    pause
    exit /b 1
  )
)
".venv\Scripts\python.exe" -c "import uvicorn, fastapi" >nul 2>nul
if errorlevel 1 (
  echo [api] Installing Python packages, takes minutes on first run...
  ".venv\Scripts\python.exe" -m pip install --upgrade pip
  ".venv\Scripts\python.exe" -m pip install -r requirements.txt
  ".venv\Scripts\python.exe" -m pip install -e ".[server,local,test]"
  if errorlevel 1 (
    echo ERROR: package install failed.
    pause
    exit /b 1
  )
)

rem The media tools. Explorer PATH never contains a winget install, so an
rem upload otherwise fails with "ffprobe is unavailable". The backend reads
rem FFMPEG_BIN and FFPROBE_BIN; set them only when PATH cannot resolve them.
where ffmpeg >nul 2>nul
if errorlevel 1 (
  if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\ffmpeg.exe" set "FFMPEG_BIN=%LOCALAPPDATA%\Microsoft\WinGet\Links\ffmpeg.exe"
  if exist "C:\ffmpeg\bin\ffmpeg.exe" set "FFMPEG_BIN=C:\ffmpeg\bin\ffmpeg.exe"
)
where ffprobe >nul 2>nul
if errorlevel 1 (
  if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\ffprobe.exe" set "FFPROBE_BIN=%LOCALAPPDATA%\Microsoft\WinGet\Links\ffprobe.exe"
  if exist "C:\ffmpeg\bin\ffprobe.exe" set "FFPROBE_BIN=C:\ffmpeg\bin\ffprobe.exe"
)
if defined FFMPEG_BIN if defined FFPROBE_BIN echo [api] using FFMPEG_BIN and FFPROBE_BIN.

if not exist ".env" (
  if exist ".env.example" (
    echo [api] creating .env from the template; add your AGNES_API_KEY inside it for live AI.
    copy /y ".env.example" ".env" >nul
  )
)
if exist ".env" (
  echo [api] starting on http://127.0.0.1:8000  docs: /docs  health: /health
  ".venv\Scripts\python.exe" -m uvicorn backend.main:app --host 127.0.0.1 --port 8000 --env-file .env --loop backend.server_loop:server_loop
) else (
  echo [api] no .env found, starting without live AI keys.
  ".venv\Scripts\python.exe" -m uvicorn backend.main:app --host 127.0.0.1 --port 8000 --loop backend.server_loop:server_loop
)
echo.
echo [api] stopped.
pause
