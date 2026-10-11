@echo off
rem Start the NOVA frontend on port 3000. Self-contained: started by START.bat,
rem or double-clicked on its own. Builds nothing; pnpm dev / npm run dev.
setlocal EnableExtensions
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo ERROR: Node.js LTS was not found on PATH.
  echo Install it from https://nodejs.org/ and re-run.
  pause
  exit /b 1
)

if not exist ".env.local" (
  if exist "app\.env.example" (
    echo [web] creating .env.local from the template, public URLs only...
    copy /y "app\.env.example" ".env.local" >nul
  )
)

if not exist "node_modules\next\package.json" (
  echo [web] installing frontend packages, takes minutes on first run...
  where pnpm >nul 2>nul
  if errorlevel 1 (
    npm install
  ) else (
    pnpm install --frozen-lockfile
  )
  if errorlevel 1 (
    echo ERROR: frontend install failed.
    pause
    exit /b 1
  )
)

echo [web] landing at http://localhost:3000/  workspace at /app
where pnpm >nul 2>nul
if errorlevel 1 (
  npm run dev
) else (
  pnpm dev
)
