@echo off
setlocal enableextensions
title Godcoder

REM ---------------------------------------------------------------------------
REM Godcoder launcher
REM Double-click this file (or run it from any prompt) to start the desktop app.
REM It starts the Vite frontend dev server and the native Tauri window.
REM The first run after a clean compiles the Rust backend; later runs are fast.
REM ---------------------------------------------------------------------------

REM Ensure Cargo (Rust) is on PATH even if it isn't configured globally.
set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"

REM Verify cargo is available before doing anything else.
where cargo >nul 2>nul
if errorlevel 1 (
    echo [Godcoder] Could not find "cargo". Install Rust from https://rustup.rs
    echo            or make sure cargo.exe is in "%USERPROFILE%\.cargo\bin".
    pause
    exit /b 1
)

REM Move to the desktop app folder, relative to this script's location.
cd /d "%~dp0apps\desktop"

REM Development mode (loads frontend from the local Vite dev server).
set "APP_ENV=development"

echo [Godcoder] Starting... a native window will open once the build finishes.
call npx tauri dev

echo.
echo [Godcoder] The app has exited.
pause
