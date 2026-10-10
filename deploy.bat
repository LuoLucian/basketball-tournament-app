@echo off
pushd "F:\项目\basketball-app"

set "VITE_SUPABASE_URL=https://zzuwpanihewhqtyywhny.supabase.co"
set "VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6dXdwYW5paGV3aHF0eXl3aG55Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0ODg3MDgsImV4cCI6MjA5MzA2NDcwOH0.RPaUDBUiwAum3nmgaqmQwWzbNhovcqnUI1CFoyGhBM8"

echo Step 1: Building...
call "F:\项目\basketball-app\node_modules\.bin\npm.cmd" run build

if %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    pause
    exit /b 1
)

echo Step 2: Deploying...
call "F:\项目\basketball-app\node_modules\.bin\npx.cmd" wrangler pages deploy dist --project-name=basketball-app --branch=main

if %ERRORLEVEL% NEQ 0 (
    echo Deploy failed!
    pause
    exit /b 1
)

echo Done!
pause
