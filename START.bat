@echo off
rem ONE double-click for everything: backend API (:8000) + TESSERA site (:3000).
rem Full startup sequence, re-runnable at any time:
rem   1. tool checks (python 3.11+, node)
rem   2. python virtual environment + backend packages (one-time installs)
rem   3. frontend packages, pnpm via corepack with npm fallback (one-time)
rem   4. .env / .env.local created from the examples when missing
rem      (.env holds secrets and is never committed; .env.local holds only
rem      the public backend URL the browser bundle needs)
rem   5. backend + frontend launch in their own windows, then this script
rem      waits for backend /health and opens the workspace in the browser.
rem If a server window flashes and closes, run run-api.bat or run-web.bat by
rem itself to read its error. install.bat remains for one-time model and
rem media-tool downloads. Close the two server windows to stop.
setlocal EnableExtensions
cd /d "%~dp0"

where python >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python 3.11 or newer was not found on PATH.
  echo Install it from https://www.python.org/downloads/ and tick "Add python.exe to PATH".
  pause
  exit /b 1
)
where node >nul 2>nul
if errorlevel 1 (
  echo ERROR: Node.js LTS was not found on PATH.
  echo Install it from https://nodejs.org/ and re-run.
  pause
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo [setup] Creating the Python virtual environment, one time only...
  python -m venv .venv
  if errorlevel 1 (
    echo ERROR: could not create .venv.
    pause
    exit /b 1
  )
)
".venv\Scripts\python.exe" -c "import uvicorn, fastapi" >nul 2>nul
if errorlevel 1 (
  echo [setup] Installing Python packages, takes minutes on first run...
  ".venv\Scripts\python.exe" -m pip install --upgrade pip
  ".venv\Scripts\python.exe" -m pip install -r requirements.txt
  ".venv\Scripts\python.exe" -m pip install -e ".[server,local,test]"
  if errorlevel 1 (
    echo ERROR: package install failed.
    pause
    exit /b 1
  )
)

if not exist "node_modules\next\package.json" (
  echo [setup] Installing frontend packages, takes minutes on first run...
  where pnpm >nul 2>nul
  if errorlevel 1 (
    call npm install
  ) else (
    call pnpm install --frozen-lockfile
  )
  if errorlevel 1 (
    echo ERROR: frontend install failed.
    pause
    exit /b 1
  )
)

if not exist ".env" (
  if exist ".env.example" (
    echo [setup] Creating .env from the template. Add your AGNES_API_KEY inside it for live AI.
    copy /y ".env.example" ".env" >nul
  ) else (
    echo NOTE: No .env and no .env.example. The backend will start without live AI keys.
  )
)
if not exist ".env.local" (
  if exist "app\.env.example" (
    echo [setup] Creating .env.local from the template, public URLs only.
    copy /y "app\.env.example" ".env.local" >nul
  )
)

echo Starting the API and the site. Two windows open.
start "Hackerring API" cmd /k run-api.bat
start "TESSERA Web" cmd /k run-web.bat

echo Waiting for the backend to answer /health, up to 3 minutes on first run...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$deadline=(Get-Date).AddMinutes(3); while((Get-Date) -lt $deadline){ try { $response=Invoke-WebRequest -Uri 'http://127.0.0.1:8000/health' -UseBasicParsing -TimeoutSec 5; if($response.StatusCode -eq 200){ exit 0 } } catch {}; Start-Sleep -Seconds 3 }; exit 1"
if errorlevel 1 (
  echo WARNING: The backend did not answer in time. Read the "Hackerring API" window for its error.
  echo The site is still starting; it will connect once the backend is up.
) else (
  echo Backend is up. Opening the workspace...
  start "" "http://localhost:3000/app"
)

echo.
echo API:       http://127.0.0.1:8000/docs   health: /health
echo Landing:   http://localhost:3000/
echo Workspace: http://localhost:3000/app
echo.
echo Close the two server windows to stop. First start can take a minute or two.
endlocal
