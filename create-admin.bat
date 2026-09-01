@echo off
title Hiww - Create admin account
cd /d "%~dp0"
echo.
echo   This creates (or updates) your admin login for the Hiww console.
echo.
call npx tsx scripts/create-admin.ts
echo.
pause
