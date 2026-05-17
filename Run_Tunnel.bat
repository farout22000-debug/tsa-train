@echo off
echo ===================================================
echo   TSA Train - Cloudflare Tunnel Quick Start
echo ===================================================
echo.
echo This will create a TEMPORARY public URL for testing.
echo For a permanent URL, you must run:
echo   cloudflared.exe tunnel login
echo.
.\cloudflared.exe tunnel --url ws://localhost:8090
pause
