@echo off
title Hiww - First-time setup
cd /d "%~dp0"
echo.
echo   This installs Hiww and creates a fresh, EMPTY database.
echo   Only run this once. Running it again will ERASE all pilot data.
echo.
set /p ok="   Type YES to continue: "
if /i not "%ok%"=="YES" ( echo Cancelled. & pause & exit /b )
echo.
echo   Installing packages...
call npm install
echo.
echo   Setting up the database...
call npm run db:setup
echo.
echo   Done. Now double-click start-hiww.bat, and in the browser log in as:
echo       admin@pilot.local  /  SecurePass123!
echo.
echo   (If that account doesn't exist yet, see docs\CONSOLE.md for the one-line
echo    command to create it.)
echo.
pause
