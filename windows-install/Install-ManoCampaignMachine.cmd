@echo off
rem Runs the installer elevated. Nothing here is added to Windows startup.
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-mano-campaign-machine.ps1"
pause
