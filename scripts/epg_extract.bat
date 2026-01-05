@echo off
setlocal

set "BASE=%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%BASE%epg.ps1"

echo.
echo ==== EPG generat cu succes ====
pause