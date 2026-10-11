@echo off
setlocal
cd /d "%~dp0"
echo NOVA - local development launcher
where pnpm >nul 2>&1
if errorlevel 1 (
  echo ERROR: pnpm not on PATH. Enable it with corepack or install pnpm before starting.
  exit /b 1
)
if not exist "node_modules\next" (
  echo ERROR: Frontend dependencies missing. From this folder run: pnpm install --frozen-lockfile
  exit /b 1
)
if not exist ".env.local" (
  echo NOTE: No repository-root .env.local. The frontend will use its offline demo mode.
)
if not exist ".venv\Scripts\python.exe" goto frontendOnly
if not exist ".env" goto frontendOnly
where ffmpeg >nul 2>&1
if errorlevel 1 (
  echo WARNING: ffmpeg not on PATH. Check FFMPEG_BIN in .env.
)
where ffprobe >nul 2>&1
if errorlevel 1 (
  echo WARNING: ffprobe not on PATH. Check FFPROBE_BIN in .env.
)
start "NOVA Backend" cmd /k ""%CD%\.venv\Scripts\python.exe" -m uvicorn backend.main:app --host 127.0.0.1 --port 8000 --env-file .env"
echo Backend: http://127.0.0.1:8000/health
goto frontend

:frontendOnly
echo WARNING: Missing .venv\Scripts\python.exe or .env; starting website without backend.
echo          To enable real processing, install backend packages and configure .env.
:frontend
start "NOVA Frontend" cmd /k "pnpm dev"
echo Landing: http://localhost:3000/
echo Workspace: http://localhost:3000/app
endlocal
