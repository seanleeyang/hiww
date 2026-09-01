@echo off
title Hiww Pilot Console
cd /d "%~dp0"
echo.
echo   Starting Hiww...
echo.
echo   A browser tab will open in a few seconds (http://localhost:3000/admin).
echo   If it shows a connection error, wait a moment and refresh.
echo.
echo   KEEP THIS WINDOW OPEN while you use the console.
echo   Close this window to stop Hiww.
echo.
start "" powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 7; Start-Process 'http://localhost:3000/admin'"
call npm run dev
echo.
echo   Hiww stopped. Press any key to close.
pause >nul
