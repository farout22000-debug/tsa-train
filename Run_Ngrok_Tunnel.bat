@echo off
title TSA Train Ngrok Tunnel
echo ===================================================
echo   TSA Train - Ngrok Persistent Tunnel
echo ===================================================
echo.
echo Make sure you have downloaded Ngrok and added it to your PATH.
echo Ensure your authentication token is configured:
echo   ngrok config add-authtoken YOUR_AUTH_TOKEN
echo.
echo Starting Ngrok Tunnel with permanent domain:
echo disallow-maximize-finless.ngrok-free.dev
echo.
echo Please leave this window open to keep the tunnel alive.
echo Press CTRL+C to stop the tunnel.
echo.
"%LocalAppData%\Microsoft\WinGet\Packages\Ngrok.Ngrok_Microsoft.Winget.Source_8wekyb3d8bbwe\ngrok.exe" http 8090 --domain=disallow-maximize-finless.ngrok-free.dev
pause
