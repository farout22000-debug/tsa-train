@echo off
title TSA Train Auto-Restarting Server

:loop
echo [%time%] Starting TSA Train Headless Server...
"C:\Godot\Godot_v4.6.1-stable_win64.exe" --path "." --headless --server

echo [%time%] Server process exited!
echo Restarting in 5 seconds... Press CTRL+C to stop completely.
timeout /t 5 /nobreak
goto loop
